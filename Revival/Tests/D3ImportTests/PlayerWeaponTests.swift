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

    func testRookieConcussionUsesExactCanonicalGunpointsAndOldOmission()
        throws
    {
        let level = try makePlayerConcussionLevel()
        let binding = try XCTUnwrap(
            level.shipDefinitions[0].playerConcussion
        )
        XCTAssertEqual(binding.gunpoints[0].localPosition, .init(
            x: 2.792_412_5,
            y: -1.186_958_9,
            z: 2.687_090_9
        ))
        XCTAssertEqual(binding.gunpoints[0].localForward, .init(
            x: 0.000_007_629_434_5,
            y: 0.000_003_337_758_7,
            z: 1
        ))
        XCTAssertEqual(binding.gunpoints[1].localPosition, .init(
            x: -2.804_046_4,
            y: -1.186_885_0,
            z: 2.687_135_2
        ))
        XCTAssertEqual(binding.gunpoints[1].localForward, .init(
            x: 0.000_008_106_278,
            y: 0.000_003_814_590_4,
            z: 1
        ))

        var oldObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(level))
                as? [String: Any]
        )
        var oldShips = try XCTUnwrap(
            oldObject["shipDefinitions"] as? [[String: Any]]
        )
        oldShips[0].removeValue(forKey: "playerConcussion")
        oldObject["shipDefinitions"] = oldShips
        let oldLevel = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(withJSONObject: oldObject)
        )
        XCTAssertNil(oldLevel.shipDefinitions[0].playerConcussion)

        var hostileShip = level.shipDefinitions[0]
        var hostile = try XCTUnwrap(hostileShip.playerConcussion)
        var gunpoints = hostile.gunpoints
        gunpoints[0] = .init(
            index: gunpoints[0].index,
            parentSubmodelIndex: gunpoints[0].parentSubmodelIndex,
            localPosition: gunpoints[0].localPosition,
            localForward: .init(x: 0, y: 0, z: 1)
        )
        hostile = replacing(hostile, gunpoints: gunpoints)
        hostileShip.playerConcussion = hostile
        XCTAssertThrowsError(try replacing(
            level,
            shipDefinitions: [hostileShip]
        ).validate()) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("default player Concussion binding")
            )
        }
    }

    func testRookieConcussionInclusiveAlternatingAndScheduledCadence()
        throws
    {
        var level = try makePlayerConcussionLevel()
        let player = try XCTUnwrap(level.objects.first {
            $0.handle == level.defaultPlayerBinding?.objectHandle
        })
        let robotIndex = try XCTUnwrap(level.objects.firstIndex {
            $0.handle == 4_112
        })
        level.objects[robotIndex].position = .init(
            x: player.position.x,
            y: player.position.y,
            z: player.position.z - 100
        )
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )
        let first = simulation.update(
            at: 0.1,
            input: .init(firesSecondaryWeapon: true)
        )
        XCTAssertEqual(first.playerConcussionMissiles.count, 1)
        let firstForward = try XCTUnwrap(
            level.shipDefinitions[0].playerConcussion?.gunpoints[0]
        ).localForward
        XCTAssertEqual(
            first.playerConcussionMissiles[0].position.x,
            player.position.x + 2.792_412_5
                + firstForward.x * 175 * first.systemsFrameDuration,
            accuracy: 0.000_01
        )
        _ = simulation.update(at: 0.5, input: .zero)
        let exactDue = simulation.update(
            at: 0.5,
            input: .init(firesSecondaryWeapon: true)
        )
        XCTAssertEqual(exactDue.systemsGameTime, 0.5, accuracy: 0.000_1)
        var object = try XCTUnwrap(
            testWorldObject(simulation.world)
        )
        var state = try XCTUnwrap(
            object["playerConcussionState"] as? [String: Any]
        )
        XCTAssertEqual(state["ammo"] as? Int, 4)
        XCTAssertEqual(
            try XCTUnwrap(state["nextFireTime"] as? Double),
            1,
            accuracy: 0.000_1
        )

        _ = simulation.update(at: 1.6, input: .zero)
        let carried = simulation.update(
            at: 1.6,
            input: .init(firesSecondaryWeapon: true)
        )
        object = try XCTUnwrap(
            testWorldObject(simulation.world)
        )
        state = try XCTUnwrap(
            object["playerConcussionState"] as? [String: Any]
        )
        XCTAssertEqual(
            try XCTUnwrap(state["nextFireTime"] as? Double),
            1.5,
            accuracy: 0.000_1
        )
        XCTAssertEqual(state["ammo"] as? Int, 3)
        XCTAssertEqual(state["nextFiringMaskIndex"] as? Int, 1)

        _ = simulation.update(at: 10, input: .zero)
        _ = simulation.update(at: 10.01, input: .zero)
        let rebased = simulation.update(
            at: 10.01,
            input: .init(firesSecondaryWeapon: true)
        )
        object = try XCTUnwrap(
            testWorldObject(simulation.world)
        )
        state = try XCTUnwrap(
            object["playerConcussionState"] as? [String: Any]
        )
        XCTAssertEqual(
            try XCTUnwrap(state["nextFireTime"] as? Double),
            Double(rebased.systemsGameTime + 0.5),
            accuracy: 0.000_1
        )
        XCTAssertEqual(state["ammo"] as? Int, 2)
        XCTAssertEqual(state["nextFiringMaskIndex"] as? Int, 0)
        XCTAssertEqual(carried.systemsGameTime, 1.6, accuracy: 0.000_1)
    }

    func testFullExplosionListDropsOnlyTheVisualAndKeepsTheShockwave()
        throws
    {
        // DoWeaponExploded makes the shockwave first (WeaponFire.cpp:3066),
        // then asks VisEffectCreate for the visual, which returns -1 when the
        // list is full (viseffect.cpp:522). The shockwave still acts.
        let level = try makePlayerConcussionLevel()
        let binding = try XCTUnwrap(
            level.shipDefinitions.first?.playerConcussion
        )
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )
        let player = simulation.world.testPlayerObject
        guard case let .room(playerRoom) = player.location else {
            return XCTFail("indoor player")
        }
        simulation.world.playerConcussionState?.missiles = [
            .init(
                creationOrdinal: 0,
                roomSourceIndex: playerRoom,
                position: player.position,
                orientation: player.orientation,
                velocity: player.orientation.forward * 0.001,
                lifeRemaining: 0.001
            ),
        ]
        simulation.world.playerConcussionState?.explosions = (1...6).map {
            .init(
                creationOrdinal: UInt64($0),
                roomSourceIndex: playerRoom,
                position: player.position,
                lifeRemaining: binding.explosionLifetime,
                shockwaveLifeRemaining: 0,
                damagedPlayer: true
            )
        }
        simulation.world.playerConcussionState?.nextCreationOrdinal = 7
        XCTAssertNoThrow(try simulation.world.validate(against: level))
        let shieldsBefore = simulation.world.shields

        let frame = simulation.update(at: 0.1, input: .zero)
        let state = try XCTUnwrap(simulation.world.playerConcussionState)
        XCTAssertEqual(state.missiles.count, 0, "the missile expired")
        XCTAssertEqual(
            state.explosions.filter(\.isPresented).map(\.creationOrdinal),
            Array(1...6),
            "the new visual was dropped, not swapped in"
        )
        let shockwave = try XCTUnwrap(state.explosions.last)
        XCTAssertEqual(shockwave.creationOrdinal, 7)
        XCTAssertFalse(shockwave.isPresented)
        XCTAssertTrue(shockwave.damagedPlayer)
        XCTAssertEqual(
            simulation.world.shields,
            shieldsBefore - binding.shockwaveDamage,
            accuracy: 0.001,
            "the new shockwave damages the player at its center"
        )
        XCTAssertEqual(frame.playerConcussionExplosions.count, 6)
        XCTAssertNoThrow(try simulation.world.validate(against: level))
        XCTAssertNoThrow(try updateMetalWorldPlan(
            try makeMetalWorldPlan(
                level: simulation.runtimeLevel,
                playerView: frame.playerView
            ),
            level: simulation.level,
            world: simulation.world,
            frame: frame,
            drawableAspect: 1
        ))
    }

    func testFullSparkListTakesNoRandomDrawsForDroppedSparks() throws {
        // CreateRandomLineSparks (viseffect.cpp:822) calls VisEffectCreate
        // first and draws ps_rand only for a spark it allocated.
        var level = try makePlayerConcussionLevel()
        let player = try XCTUnwrap(level.objects.first {
            $0.handle == level.defaultPlayerBinding?.objectHandle
        })
        guard case let .room(playerRoom) = player.location else {
            return XCTFail("indoor player")
        }
        let robotIndex = try XCTUnwrap(level.objects.firstIndex {
            $0.handle == 4_112
        })
        level.objects[robotIndex].position = .init(
            x: player.position.x + player.orientation.forward.x * 15,
            y: player.position.y + player.orientation.forward.y * 15,
            z: player.position.z + player.orientation.forward.z * 15
        )
        level.objects[robotIndex].location = player.location
        func run(sparks: Int) throws -> (UInt32, Int) {
            let simulation = GameSession(
                level: level,
                presentationReadyTimestamp: 0,
                authoritativeRandomSeed: 0x1234_5678
            )
            simulation.world.playerConcussionState?.sparks =
                (0..<sparks).map {
                    .init(
                        creationOrdinal: UInt64($0),
                        roomSourceIndex: playerRoom,
                        position: player.position,
                        velocity: player.orientation.up,
                        size: 1,
                        lifetime: 2,
                        lifeRemaining: 2
                    )
                }
            simulation.world.playerConcussionState?.nextCreationOrdinal =
                UInt64(sparks)
            _ = simulation.update(
                at: 0.1,
                input: .init(firesSecondaryWeapon: true)
            )
            let state = try XCTUnwrap(simulation.world.playerConcussionState)
            return (
                simulation.world.authoritativeRandomState,
                state.sparks.count - sparks
            )
        }
        let (openState, created) = try run(sparks: 0)
        XCTAssertTrue((3...8).contains(created))
        let (fullState, dropped) = try run(sparks: 48)
        XCTAssertEqual(dropped, 0)
        var advanced = fullState
        for _ in 0..<(created * 6) {
            advanced = advanced &* 214_013 &+ 2_531_011
        }
        XCTAssertEqual(
            advanced,
            openState,
            "only the allocated sparks take their six draws"
        )
    }

    func testRookieConcussionLaunchImpactShockwaveAndContinuationAreDeterministic()
        throws
    {
        var level = try makePlayerConcussionLevel()
        let player = try XCTUnwrap(level.objects.first {
            $0.handle == level.defaultPlayerBinding?.objectHandle
        })
        let robotIndex = try XCTUnwrap(level.objects.firstIndex {
            $0.handle == 4_112
        })
        level.objects[robotIndex].position = .init(
            x: player.position.x + player.orientation.forward.x * 15,
            y: player.position.y + player.orientation.forward.y * 15,
            z: player.position.z + player.orientation.forward.z * 15
        )
        level.objects[robotIndex].location = player.location

        let seed = GameSession(
            level: level,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 0x1234_5678
        )
        let continuationObject = try XCTUnwrap(
            testWorldObject(seed.world)
        )
        let reached = try decodeTestWorld(continuationObject)
        let simulation = try GameSession(
            level: level,
            world: reached.rebased(onto: level),
            resumedAtTimestamp: 100
        )
        let randomStateBefore = try XCTUnwrap(
            continuationObject["authoritativeRandomState"] as? NSNumber
        ).uint32Value

        let impact = simulation.update(
            at: 100.1,
            input: .init(firesSecondaryWeapon: true)
        )
        XCTAssertEqual(impact.playerConcussionMissiles.count, 0)
        XCTAssertEqual(impact.playerConcussionExplosions.count, 1)
        XCTAssertEqual(
            impact.playerConcussionExplosions[0].texture.sourceName,
            "ExplosionE"
        )
        XCTAssertEqual(
            impact.trainingOpeningFeedback.compactMap(\.soundSourceName),
            ["concmissilefire7.wav", "Explode1.wav"]
        )
        XCTAssertTrue((3...8).contains(impact.playerConcussionSparks.count))

        var impactContinuation = try XCTUnwrap(
            testWorldObject(simulation.world)
        )
        let concussionState = try XCTUnwrap(
            impactContinuation["playerConcussionState"] as? [String: Any]
        )
        XCTAssertEqual(concussionState["ammo"] as? Int, 5)
        XCTAssertEqual(concussionState["nextFiringMaskIndex"] as? Int, 1)
        let robotAfterDirect = try XCTUnwrap(
            impactContinuation["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        XCTAssertEqual(robotAfterDirect["robotShields"] as? Double, 46)
        let sparkStates = try XCTUnwrap(
            concussionState["sparks"] as? [[String: Any]]
        )
        let firstSpark = try XCTUnwrap(sparkStates.first)
        XCTAssertNotNil(firstSpark["position"] as? [String: Any])
        XCTAssertNotNil(firstSpark["velocity"] as? [String: Any])
        XCTAssertTrue((0.7...1.06).contains(
            try XCTUnwrap(firstSpark["size"] as? Double)
        ))
        XCTAssertTrue((1...2.35).contains(
            try XCTUnwrap(firstSpark["lifetime"] as? Double)
        ))

        var expectedRandomState = randomStateBefore
        for _ in 0..<(1 + impact.playerConcussionSparks.count * 6) {
            expectedRandomState = expectedRandomState &* 214_013 &+ 2_531_011
        }
        XCTAssertEqual(
            (impactContinuation["authoritativeRandomState"] as? NSNumber)?
                .uint32Value,
            expectedRandomState
        )

        let premature = simulation.update(
            at: 100.2,
            input: .init(firesSecondaryWeapon: true)
        )
        XCTAssertEqual(premature.playerConcussionMissiles.count, 0)
        impactContinuation = try XCTUnwrap(
            testWorldObject(simulation.world)
        )
        let prematureState = try XCTUnwrap(
            impactContinuation["playerConcussionState"] as? [String: Any]
        )
        XCTAssertEqual(prematureState["ammo"] as? Int, 5)
        let robotAfterShockwave = try XCTUnwrap(
            impactContinuation["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        let explosion = impact.playerConcussionExplosions[0]
        let robotPosition = level.objects[robotIndex].position
        let robotRadius = try XCTUnwrap(
            level.trainingRobotGuidebotChain?.combat.robotCollisionRadius
        )
        let surfaceDistance = max(
            0,
            sqrt(
                pow(robotPosition.x - explosion.position.x, 2)
                    + pow(robotPosition.y - explosion.position.y, 2)
                    + pow(robotPosition.z - explosion.position.z, 2)
            ) - robotRadius
        )
        let expectedShockwaveDamage = 19 * (1 - surfaceDistance / 32) * 1.5
        XCTAssertEqual(
            try XCTUnwrap(robotAfterShockwave["robotShields"] as? Double),
            Double(46 - expectedShockwaveDamage),
            accuracy: 0.000_1
        )
        let movedState = try XCTUnwrap(
            prematureState["sparks"] as? [[String: Any]]
        )
        XCTAssertNotEqual(
            movedState.first?["position"] as? [String: Double],
            firstSpark["position"] as? [String: Double]
        )

        let savedContinuation = simulation.world
        let expectedRestoredFrame = simulation.update(
            at: 100.3,
            input: .zero
        )
        let restored = try GameSession(
            level: level,
            world: savedContinuation.rebased(onto: level),
            resumedAtTimestamp: 200
        )
        let restoredFrame = restored.update(at: 200, input: .zero)
        XCTAssertEqual(
            restoredFrame.playerConcussionExplosions,
            expectedRestoredFrame.playerConcussionExplosions
        )
        XCTAssertFalse(
            restored.update(at: 200.1, input: .zero)
                .trainingOpeningFeedback.contains {
                    $0.soundSourceName == "concmissilefire7.wav"
                }
        )
    }

    func testRookieConcussionBlockedAndExhaustedAttemptsAreSideEffectFree()
        throws
    {
        var level = try makePlayerConcussionLevel()
        let player = try XCTUnwrap(level.objects.first {
            $0.handle == level.defaultPlayerBinding?.objectHandle
        })
        let gunpoint = try XCTUnwrap(
            level.shipDefinitions.first?.playerConcussion?.gunpoints.first
        )
        let blockerIndex = try XCTUnwrap(level.objects.firstIndex {
            $0.handle == 4_112
        })
        let local = gunpoint.localPosition
        let offset = Vector3(
            x: player.orientation.right.x * local.x
                + player.orientation.up.x * local.y
                + player.orientation.forward.x * local.z,
            y: player.orientation.right.y * local.x
                + player.orientation.up.y * local.y
                + player.orientation.forward.y * local.z,
            z: player.orientation.right.z * local.x
                + player.orientation.up.z * local.y
                + player.orientation.forward.z * local.z
        )
        level.objects[blockerIndex].position = .init(
            x: player.position.x + offset.x * 0.5,
            y: player.position.y + offset.y * 0.5,
            z: player.position.z + offset.z * 0.5
        )
        level.objects[blockerIndex].location = player.location

        let blockedSimulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 0x8765_4321
        )
        let before = try XCTUnwrap(
            testWorldObject(blockedSimulation.world)
        )
        let blocked = blockedSimulation.update(
            at: 0.1,
            input: .init(firesSecondaryWeapon: true)
        )
        XCTAssertTrue(blocked.playerConcussionMissiles.isEmpty)
        XCTAssertTrue(blocked.playerConcussionExplosions.isEmpty)
        XCTAssertFalse(blocked.trainingOpeningFeedback.contains {
            $0.soundSourceName == "concmissilefire7.wav"
        })
        var after = try XCTUnwrap(
            testWorldObject(blockedSimulation.world)
        )
        let blockedState = try XCTUnwrap(
            after["playerConcussionState"] as? [String: Any]
        )
        XCTAssertEqual(blockedState["ammo"] as? Int, 6)
        XCTAssertEqual(blockedState["nextFiringMaskIndex"] as? Int, 0)
        XCTAssertEqual(
            (after["authoritativeRandomState"] as? NSNumber)?.uint32Value,
            (before["authoritativeRandomState"] as? NSNumber)?.uint32Value
        )

        var exhaustedState = blockedState
        exhaustedState["ammo"] = 0
        exhaustedState["nextFireTime"] = 0
        after["playerConcussionState"] = exhaustedState
        let exhaustedSimulation = try GameSession(
            level: level,
            world: (decodeTestWorld(after)).rebased(onto: level),
            resumedAtTimestamp: 10
        )
        let exhausted = exhaustedSimulation.update(
            at: 10.1,
            input: .init(firesSecondaryWeapon: true)
        )
        XCTAssertEqual(
            exhausted.trainingOpeningFeedback.flatMap(\.hudMessages),
            ["Not enough projectiles available!"]
        )
        XCTAssertTrue(exhausted.playerConcussionMissiles.isEmpty)
        let exhaustedAfter = try XCTUnwrap(
            testWorldObject(exhaustedSimulation.world)
        )
        XCTAssertEqual(
            (exhaustedAfter["authoritativeRandomState"] as? NSNumber)?
                .uint32Value,
            (after["authoritativeRandomState"] as? NSNumber)?.uint32Value
        )
    }

    func testRookieConcussionTimeoutAndHostileContinuationAreBounded()
        throws
    {
        let level = try makePlayerConcussionLevel()
        let player = try XCTUnwrap(level.objects.first {
            $0.handle == level.defaultPlayerBinding?.objectHandle
        })
        let playerRoom = try XCTUnwrap({ () -> Int? in
            guard case let .room(sourceIndex) = player.location else {
                return nil
            }
            return sourceIndex
        }())
        let seed = GameSession(
            level: level,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 0x1111_2222
        )
        var continuationObject = try XCTUnwrap(
            testWorldObject(seed.world)
        )
        var concussionState = try XCTUnwrap(
            continuationObject["playerConcussionState"] as? [String: Any]
        )
        let missile: [String: Any] = [
            "creationOrdinal": 0,
            "roomSourceIndex": playerRoom,
            "position": try XCTUnwrap(
                continuationObject["playerPosition"] as? [String: Any]
            ),
            "orientation": try XCTUnwrap(
                continuationObject["playerOrientation"] as? [String: Any]
            ),
            "velocity": ["x": 0, "y": 0, "z": 0],
            "lifeRemaining": 0.05,
        ]
        concussionState["missiles"] = [missile]
        concussionState["ammo"] = 5
        concussionState["nextCreationOrdinal"] = 1
        continuationObject["playerConcussionState"] = concussionState
        let timeoutContinuation = try decodeTestWorld(continuationObject)
        let timeoutSimulation = try GameSession(
            level: level,
            world: timeoutContinuation.rebased(onto: level),
            resumedAtTimestamp: 10
        )
        let timeout = timeoutSimulation.update(at: 10.1, input: .zero)
        XCTAssertTrue(timeout.playerConcussionMissiles.isEmpty)
        XCTAssertEqual(timeout.playerConcussionExplosions.count, 1)
        XCTAssertTrue(timeout.trainingOpeningFeedback.contains {
            $0.soundSourceName == "Explode1.wav"
        })

        concussionState["missiles"] = [missile, missile]
        concussionState["ammo"] = 4
        continuationObject["playerConcussionState"] = concussionState

        var impossibleConservation = concussionState
        impossibleConservation["missiles"] = (0..<6).map { ordinal in
            var distinct = missile
            distinct["creationOrdinal"] = ordinal
            return distinct
        }
        impossibleConservation["ammo"] = 6
        impossibleConservation["nextCreationOrdinal"] = 6
        continuationObject["playerConcussionState"] = impossibleConservation

    }

    func testScript030RestoresAfterSameFrameConcussionImpact() throws {
        // The concussion level with the Training level module.
        let level = addingTrainingMissionScripting(
            try makePlayerConcussionLevel()
        )
        let player = try XCTUnwrap(level.objects.first {
            $0.handle == level.defaultPlayerBinding?.objectHandle
        })
        let playerRoom = try XCTUnwrap({ () -> Int? in
            guard case let .room(sourceIndex) = player.location else {
                return nil
            }
            return sourceIndex
        }())
        let seed = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )
        var continuationObject = try XCTUnwrap(
            testWorldObject(seed.world)
        )
        continuationObject["shields"] = 1
        // After Script 014 (TrainingMission.cpp:1814-1817).
        continuationObject["playerControllerBitflags"] = 63
        var concussionState = try XCTUnwrap(
            continuationObject["playerConcussionState"] as? [String: Any]
        )
        concussionState["explosions"] = [[
            "creationOrdinal": 0,
            "roomSourceIndex": playerRoom,
            "position": try XCTUnwrap(
                continuationObject["playerPosition"] as? [String: Any]
            ),
            "lifeRemaining": 0.5,
            "shockwaveLifeRemaining": 0.1,
            "damagedObjectHandles": [],
            "damagedPlayer": false,
            "isPresented": true,
        ]]
        concussionState["ammo"] = 5
        concussionState["nextCreationOrdinal"] = 1
        continuationObject["playerConcussionState"] = concussionState
        var continuation = try decodeTestWorld(continuationObject)
            .rebased(onto: level)
        var counters = try XCTUnwrap(continuation.testTrainingMission)
        counters.script014Count = 1
        continuation.levelModule = .trainingMission(counters)
        let simulation = try GameSession(
            level: level,
            world: continuation,
            resumedAtTimestamp: 10
        )
        // The impact lands during the object frames (1 - 19). Script 030
        // runs later in the level EVT_INTERVAL (GameLoop.cpp:3013,
        // TrainingMission.cpp:1386-1388) and restores 50 in the same frame.
        let frame = simulation.update(at: 10.1, input: .zero)
        XCTAssertEqual(frame.shields, 50)
        XCTAssertEqual(simulation.world.testTrainingMission?.script030Count, 1)
        // The next frame's shields are 50, so Script 030 does not run again.
        _ = simulation.update(at: 10.2, input: .zero)
        XCTAssertEqual(simulation.world.testTrainingMission?.script030Count, 1)
    }

    @MainActor
    func testHeldPrimaryFirePublishesUntilReleaseAndKeepsScheduledCadence()
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

        var level = makeTrainingRobotGuidebotLevel()
        let player = try XCTUnwrap(
            level.objects.first {
                $0.handle == level.defaultPlayerBinding?.objectHandle
            }
        )
        let robotIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 4_112 }
        )
        level.objects[robotIndex].position = .init(
            x: player.position.x - player.orientation.forward.x * 100,
            y: player.position.y - player.orientation.forward.y * 100,
            z: player.position.z - player.orientation.forward.z * 100
        )
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 0x1234_5678
        )

        var frame = simulation.update(
            at: 0.01,
            input: .init(yaw: 1, firesPrimaryWeapon: true)
        )
        let initialPosition = player.position
        XCTAssertNotEqual(
            frame.playerView.camera.target,
            Vector3(
                x: initialPosition.x + player.orientation.forward.x,
                y: initialPosition.y + player.orientation.forward.y,
                z: initialPosition.z + player.orientation.forward.z
            )
        )
        XCTAssertEqual(simulation.energy, 99.85, accuracy: 0.000_01)
        var continuationObject = try XCTUnwrap(
            testWorldObject(simulation.world)
        )
        var guidebotState = try XCTUnwrap(
            continuationObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        let firstProjectiles = try XCTUnwrap(
            guidebotState["projectiles"] as? [[String: Any]]
        )
        XCTAssertEqual(firstProjectiles.count, 2)
        let firstVolleyPositions = try firstProjectiles.map { projectile in
            let position = try XCTUnwrap(
                projectile["position"] as? [String: Any]
            )
            return Vector3(
                x: Float(try XCTUnwrap(position["x"] as? Double)),
                y: Float(try XCTUnwrap(position["y"] as? Double)),
                z: Float(try XCTUnwrap(position["z"] as? Double))
            )
        }
        let gunpoints = try XCTUnwrap(
            level.trainingRobotGuidebotChain?.combat.gunpoints
        )
        let projectileAdvance = try XCTUnwrap(
            level.trainingRobotGuidebotChain?.combat.projectileSpeed
        ) * 0.1
        let expectedPositions = gunpoints.map { gunpoint in
            Vector3(
                x: initialPosition.x
                    + player.orientation.right.x * gunpoint.x
                    + player.orientation.up.x * gunpoint.y
                    + player.orientation.forward.x
                        * (
                            gunpoint.z + projectileAdvance
                        ),
                y: initialPosition.y
                    + player.orientation.right.y * gunpoint.x
                    + player.orientation.up.y * gunpoint.y
                    + player.orientation.forward.y
                        * (
                            gunpoint.z + projectileAdvance
                        ),
                z: initialPosition.z
                    + player.orientation.right.z * gunpoint.x
                    + player.orientation.up.z * gunpoint.y
                    + player.orientation.forward.z
                        * (
                            gunpoint.z + projectileAdvance
                        )
            )
        }
        XCTAssertEqual(firstVolleyPositions, expectedPositions)

        frame = simulation.update(
            at: 0.257,
            input: .init(firesPrimaryWeapon: true)
        )
        XCTAssertEqual(simulation.energy, 99.85, accuracy: 0.000_01)
        frame = simulation.update(
            at: 0.267,
            input: .init(firesPrimaryWeapon: true)
        )
        XCTAssertEqual(simulation.energy, 99.7, accuracy: 0.000_01)

        continuationObject = try XCTUnwrap(
            testWorldObject(simulation.world)
        )
        guidebotState = try XCTUnwrap(
            continuationObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        XCTAssertEqual(
            try XCTUnwrap(
                guidebotState["projectiles"] as? [[String: Any]]
            ).count,
            4
        )
        XCTAssertEqual(
            try XCTUnwrap(
                guidebotState["nextPrimaryFireTime"] as? Double
            ),
            0.5,
            accuracy: 0.000_000_1
        )
        XCTAssertEqual(
            continuationObject["authoritativeRandomState"] as? Int,
            Int(0x1234_5678)
        )

        _ = simulation.update(at: 9, input: .zero)
        _ = simulation.update(at: 9.016, input: .zero)
        frame = simulation.update(
            at: 9.032,
            input: .init(firesPrimaryWeapon: true)
        )
        XCTAssertEqual(simulation.energy, 99.55, accuracy: 0.000_01)
        let rebasedObject = try XCTUnwrap(
            testWorldObject(simulation.world)
        )
        let rebasedGuidebot = try XCTUnwrap(
            rebasedObject["trainingRobotGuidebotState"] as? [String: Any]
        )
        XCTAssertEqual(
            try XCTUnwrap(
                rebasedGuidebot["nextPrimaryFireTime"] as? Double
            ),
            9.266,
            accuracy: 0.000_001
        )

        XCTAssertFalse(
            trainingPlayerControlMask(
                galleryWasTriggered: true,
                controlsWereRestored: false,
                controllerBitflags: .all
            ).contains(.primaryWeapon)
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

        let oldPackage = makeTrainingGuidebotYellowFlareLevel()
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
        _ = legacyGuidebot.update(
            at: 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        var legacyObject = try XCTUnwrap(
            testWorldObject(legacyGuidebot.world)
        )
        var legacyGuidebotState = try XCTUnwrap(
            legacyObject["trainingRobotGuidebotState"] as? [String: Any]
        )
        legacyGuidebotState["guidebotMode"] = "ambient"
        legacyGuidebotState["guidebotModeTime"] = 0.1
        legacyGuidebotState["nextAmbientTime"] = 100.0
        legacyGuidebotState["timeUntilNextFlare"] = 0.05
        legacyGuidebotState["nextPowerupCheckTime"] = 100.0
        legacyGuidebotState["yellowFlareGoalSlots"] = [
            "slot1IsUsed": true,
            "slot2IsUsed": false,
            "slot3IsUsed": false,
        ]
        legacyGuidebotState["yellowFlares"] = []
        legacyObject["trainingRobotGuidebotState"] = legacyGuidebotState
        let restoredLegacyGuidebot = try GameSession(
            level: oldPackage,
            world: (decodeTestWorld(legacyObject)).rebased(onto: oldPackage),
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
        let level = try makePlayerYellowFlareLevel()
        let seed: UInt32 = 0x3141_5926
        let initial = GameSession(
            level: level,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: seed
        )
        _ = initial.update(
            at: 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        var dueObject = try XCTUnwrap(
            testWorldObject(initial.world)
        )
        var dueGuidebot = try XCTUnwrap(
            dueObject["trainingRobotGuidebotState"] as? [String: Any]
        )
        dueGuidebot["guidebotMode"] = "ambient"
        dueGuidebot["guidebotModeTime"] = 0.1
        dueGuidebot["nextAmbientTime"] = 100.0
        dueGuidebot["timeUntilNextFlare"] = 0.05
        dueGuidebot["nextPowerupCheckTime"] = 100.0
        dueGuidebot["yellowFlareGoalSlots"] = [
            "slot1IsUsed": true,
            "slot2IsUsed": false,
            "slot3IsUsed": false,
        ]
        dueGuidebot["yellowFlares"] = []
        dueObject["trainingRobotGuidebotState"] = dueGuidebot
        let due = try GameSession(
            level: level,
            world: (decodeTestWorld(dueObject)).rebased(onto: level),
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

        var mixedObject = try XCTUnwrap(
            testWorldObject(due.world)
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

    func testConcussionKillOfDestroyRobotOpensGalleryBarrier() throws {
        // A real concussion missile kills DestroyBot2 (4112). The kill opens
        // the gallery barrier portals and their reciprocals, as the
        // double-sided aPortalRenderSet does (DallasFuncs.cpp:1098).
        var level = try makePlayerConcussionLevel()
        // The room graph must be reciprocal, as Level.validate requires
        // (invalidPortal, nonreciprocalPortal).
        for room in level.rooms {
            for (portalIndex, portal) in room.portals.enumerated() {
                let connected = try XCTUnwrap(level.rooms.first {
                    $0.sourceIndex == portal.connectedRoom
                })
                XCTAssertTrue(
                    connected.portals.indices.contains(portal.connectedPortal),
                    "room \(room.sourceIndex) portal \(portalIndex)"
                )
                guard connected.portals.indices.contains(
                    portal.connectedPortal
                ) else { continue }
                let inverse = connected.portals[portal.connectedPortal]
                XCTAssertEqual(inverse.connectedRoom, room.sourceIndex)
                XCTAssertEqual(inverse.connectedPortal, portalIndex)
            }
        }
        let player = try XCTUnwrap(level.objects.first {
            $0.handle == level.defaultPlayerBinding?.objectHandle
        })
        let robotIndex = try XCTUnwrap(level.objects.firstIndex {
            $0.handle == 4_112
        })
        level.objects[robotIndex].position = .init(
            x: player.position.x + player.orientation.forward.x * 15,
            y: player.position.y + player.orientation.forward.y * 15,
            z: player.position.z + player.orientation.forward.z * 15
        )
        level.objects[robotIndex].location = player.location
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 0x1234_5678
        )
        // One direct hit (9) kills it. The shockwave pushes the robot off
        // the line of fire, so later missiles would miss.
        simulation.world.trainingRobotGuidebotState?.robotShields = 5

        var time: Double = 0
        while simulation.world.trainingRobotGuidebotState?.robotWasDestroyed
            == false, time < 10
        {
            time += 0.1
            _ = simulation.update(
                at: time,
                input: .init(firesSecondaryWeapon: true)
            )
        }
        XCTAssertEqual(
            simulation.world.trainingRobotGuidebotState?.robotWasDestroyed,
            true
        )
        for _ in 0..<30 {
            time += 0.1
            _ = simulation.update(at: time, input: .zero)
        }

        let barrier = try XCTUnwrap(level.trainingGalleryBarrier)
        let roomIndex = try XCTUnwrap(level.rooms.firstIndex {
            $0.sourceIndex == barrier.barrierRoomSourceIndex
        })
        for portalIndex in barrier.orderedPortalIndices {
            XCTAssertEqual(
                simulation.world.rooms[roomIndex].portalFlags[portalIndex] & 1,
                0
            )
            let portal = level.rooms[roomIndex].portals[portalIndex]
            let connectedIndex = try XCTUnwrap(level.rooms.firstIndex {
                $0.sourceIndex == portal.connectedRoom
            })
            XCTAssertEqual(
                simulation.world.rooms[connectedIndex]
                    .portalFlags[portal.connectedPortal] & 1,
                0
            )
        }
        XCTAssertNoThrow(try simulation.world.validate(against: level))
    }
}
