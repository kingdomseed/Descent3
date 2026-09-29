import XCTest

extension WorldRenderingTests {
    func testGuidebotYellowFlareResetsBeforeEligibilityThenRetainsCarrierAndFirstParticle()
        throws
    {
        let level = makeTrainingGuidebotYellowFlareLevel()
        let initialRandomState: UInt32 = 0x1357_9BDF
        func nextState(_ state: UInt32) -> UInt32 {
            state &* 214_013 &+ 2_531_011
        }
        func expectedMotion(
            position: Vector3,
            velocity: Vector3,
            duration: Float
        ) -> (position: Vector3, velocity: Vector3) {
            let mass: Float = 0.1
            let drag: Float = 0.1
            let force = Vector3(
                x: 0,
                y: level.metadata.gravity * mass,
                z: 0
            )
            func component(
                _ position: Float,
                _ velocity: Float,
                _ force: Float
            ) -> (Float, Float) {
                let position = Double(position)
                let velocity = Double(velocity)
                let force = Double(force)
                let mass = Double(mass)
                let drag = Double(drag)
                let duration = Double(duration)
                let terminalVelocity = force / drag
                let massOverDrag = mass / drag
                let decay = exp(-(drag / mass) * duration)
                return (
                    Float(
                        position + terminalVelocity * duration
                            + massOverDrag
                                * (velocity - terminalVelocity)
                                * (1 - decay)
                    ),
                    Float(
                        (velocity - terminalVelocity) * decay
                            + terminalVelocity
                    )
                )
            }
            let x = component(position.x, velocity.x, force.x)
            let y = component(position.y, velocity.y, force.y)
            let z = component(position.z, velocity.z, force.z)
            return (
                .init(x: x.0, y: y.0, z: z.0),
                .init(x: x.1, y: y.1, z: z.1)
            )
        }
        func expectedParticleMotion(
            position: Vector3,
            velocity: Vector3,
            duration: Float
        ) -> (position: Vector3, velocity: Vector3) {
            func component(
                _ position: Float,
                _ velocity: Float,
                _ force: Float
            ) -> (Float, Float) {
                let terminalVelocity = Double(force) / 0.1
                let massOverDrag = 100.0 / 0.1
                let decay = exp(-(0.1 / 100.0) * Double(duration))
                return (
                    Float(
                        Double(position)
                            + terminalVelocity * Double(duration)
                            + massOverDrag
                                * (Double(velocity) - terminalVelocity)
                                * (1 - decay)
                    ),
                    Float(
                        (Double(velocity) - terminalVelocity) * decay
                            + terminalVelocity
                    )
                )
            }
            let x = component(position.x, velocity.x, 0)
            let y = component(position.y, velocity.y, -3_220)
            let z = component(position.z, velocity.z, 0)
            return (
                .init(x: x.0, y: y.0, z: z.0),
                .init(x: x.1, y: y.1, z: z.1)
            )
        }
        func continuationObject(
            _ continuation: GameWorld
        ) throws -> [String: Any] {
            try XCTUnwrap(
                testWorldObject(continuation)
            )
        }
        func preparedContinuation(
            from continuation: GameWorld,
            helperSlotsAreUsed: Bool,
            randomState: UInt32
        ) throws -> GameWorld {
            var object = try continuationObject(continuation)
            object["authoritativeRandomState"] = NSNumber(value: randomState)
            var state = try XCTUnwrap(
                object["trainingRobotGuidebotState"] as? [String: Any]
            )
            state["guidebotMode"] = "ambient"
            state["guidebotModeTime"] = 0.1
            state["nextAmbientTime"] = 100.0
            state["timeUntilNextFlare"] = 0.05
            state["nextPowerupCheckTime"] = 100.0
            state["yellowFlareGoalSlots"] = [
                "slot1IsUsed": true,
                "slot2IsUsed": helperSlotsAreUsed,
                "slot3IsUsed": helperSlotsAreUsed,
            ]
            state["yellowFlares"] = []
            object["trainingRobotGuidebotState"] = state
            return try decodeTestWorld(object)
        }
        func randomState(
            in continuation: GameWorld
        ) throws -> UInt32 {
            let object = try continuationObject(continuation)
            return try XCTUnwrap(
                (object["authoritativeRandomState"] as? NSNumber)?
                    .uint32Value
            )
        }

        let seedSimulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )
        _ = seedSimulation.update(
            at: 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        _ = try GameSession(
            level: level,
            world: seedSimulation.world.rebased(onto: level),
            resumedAtTimestamp: 9
        )
        let blockedStart = try preparedContinuation(
            from: seedSimulation.world,
            helperSlotsAreUsed: true,
            randomState: initialRandomState
        )
        let blocked = try GameSession(
            level: level,
            world: blockedStart.rebased(onto: level),
            resumedAtTimestamp: 10
        )
        let blockedFrame = blocked.update(at: 10.1, input: .zero)
        let stateAfterBlockedReset = nextState(initialRandomState)
        XCTAssertEqual(
            try randomState(in: blocked.world),
            stateAfterBlockedReset
        )
        XCTAssertTrue(blockedFrame.trainingGuidebotYellowFlares.isEmpty)
        XCTAssertTrue(blockedFrame.trainingGuidebotYellowFlareParticles.isEmpty)
        XCTAssertFalse(blockedFrame.trainingOpeningFeedback.contains {
            $0.soundSourceName == "Flare.wav"
        })

        let eligibleStart = try preparedContinuation(
            from: blocked.world,
            helperSlotsAreUsed: false,
            randomState: stateAfterBlockedReset
        )
        let eligible = try GameSession(
            level: level,
            world: eligibleStart.rebased(onto: level),
            resumedAtTimestamp: 20
        )
        let fired = eligible.update(at: 20.1, input: .zero)
        let stateAfterEligibleReset = nextState(stateAfterBlockedReset)
        XCTAssertEqual(
            try randomState(in: eligible.world),
            stateAfterEligibleReset
        )
        XCTAssertEqual(
            fired.trainingOpeningFeedback.filter {
                $0.soundSourceName == "Flare.wav"
            }.count,
            1
        )
        let carrierAtCreation = try XCTUnwrap(
            fired.trainingGuidebotYellowFlares.only
        )
        XCTAssertTrue(fired.trainingGuidebotYellowFlareParticles.isEmpty)
        XCTAssertEqual(carrierAtCreation.lightDistance, 35)

        let emitted = eligible.update(at: 20.2, input: .zero)
        var expectedDrawState = stateAfterEligibleReset
        let particleAndLightDraws = (0..<7).map { _ -> UInt32 in
            expectedDrawState = nextState(expectedDrawState)
            return (expectedDrawState >> 16) & 0x7fff
        }
        XCTAssertEqual(
            try randomState(in: eligible.world),
            expectedDrawState
        )
        XCTAssertFalse(emitted.trainingOpeningFeedback.contains {
            $0.soundSourceName == "Flare.wav"
        })
        let carrier = try XCTUnwrap(
            emitted.trainingGuidebotYellowFlares.only
        )
        XCTAssertEqual(carrier.model.sourceName, "FlareYellowBright.OOF")
        XCTAssertEqual(carrier.collisionRadius, 0.1)
        XCTAssertEqual(
            carrier.velocity,
            .init(
                x: carrier.orientation.forward.x * 100,
                y: carrier.orientation.forward.y * 100,
                z: carrier.orientation.forward.z * 100
            )
        )
        XCTAssertEqual(carrier.sourceLightDistance, 35)
        XCTAssertTrue((33...37).contains(carrier.lightDistance))
        let particle = try XCTUnwrap(
            emitted.trainingGuidebotYellowFlareParticles.only
        )
        XCTAssertEqual(particle.texture.sourceName, "yellowspark")
        let rawVelocity = Vector3(
            x: Float(Int(particleAndLightDraws[0] % 100) - 50),
            y: Float(particleAndLightDraws[1] % 100),
            z: Float(Int(particleAndLightDraws[2] % 100) - 50)
        )
        let rawMagnitude = sqrt(
            rawVelocity.x * rawVelocity.x
                + rawVelocity.y * rawVelocity.y
                + rawVelocity.z * rawVelocity.z
        )
        let expectedSpeed = Float(10 + particleAndLightDraws[3] % 10)
        let initialParticleVelocity = Vector3(
            x: rawVelocity.x / rawMagnitude * expectedSpeed,
            y: rawVelocity.y / rawMagnitude * expectedSpeed,
            z: rawVelocity.z / rawMagnitude * expectedSpeed
        )
        let initialParticlePosition = Vector3(
            x: carrierAtCreation.position.x
                - carrierAtCreation.orientation.forward.x * 0.1,
            y: carrierAtCreation.position.y
                - carrierAtCreation.orientation.forward.y * 0.1,
            z: carrierAtCreation.position.z
                - carrierAtCreation.orientation.forward.z * 0.1
        )
        let expectedParticle = expectedParticleMotion(
            position: initialParticlePosition,
            velocity: initialParticleVelocity,
            duration: 0.1
        )
        let emittedContinuationState = try XCTUnwrap(
            try continuationObject(eligible.world)[
                "trainingRobotGuidebotState"
            ] as? [String: Any]
        )
        let persistedParticle = try XCTUnwrap(
            (emittedContinuationState["yellowFlareParticles"]
                as? [[String: Any]])?.only
        )
        let persistedVelocity = try XCTUnwrap(
            persistedParticle["velocity"] as? [String: NSNumber]
        )
        XCTAssertEqual(
            try XCTUnwrap(persistedVelocity["x"]?.floatValue),
            expectedParticle.velocity.x,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            try XCTUnwrap(persistedVelocity["y"]?.floatValue),
            expectedParticle.velocity.y,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            try XCTUnwrap(persistedVelocity["z"]?.floatValue),
            expectedParticle.velocity.z,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            particle.size,
            0.2
                + Float(Int(particleAndLightDraws[4] % 11) - 5)
                    * 0.02,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            particle.lifetime,
            0.3
                + Float(Int(particleAndLightDraws[5] % 11) - 5)
                    * 0.03,
            accuracy: 0.000_001
        )
        XCTAssertEqual(particle.sourceSize, 0.2)
        XCTAssertEqual(particle.sourceLifetime, 0.3)
        XCTAssertEqual(
            particle.position.x,
            expectedParticle.position.x,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            particle.position.y,
            expectedParticle.position.y,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            particle.position.z,
            expectedParticle.position.z,
            accuracy: 0.000_001
        )
        XCTAssertEqual(particle.opacity, 1)
        XCTAssertEqual(
            carrier.lightDistance,
            35 + Float(Int(particleAndLightDraws[6] % 5) - 2)
        )
        XCTAssertNotEqual(carrier.position, carrierAtCreation.position)
        let preparedPlan = try makeMetalWorldPlan(
            level: eligible.runtimeLevel,
            playerView: emitted.playerView
        )
        let retainedPlan = try updateMetalWorldPlan(
            preparedPlan,
            level: eligible.level,
            objects: eligible.world.objects,
            roomStates: eligible.world.rooms,
            playerView: emitted.playerView,
            trainingGuidebotYellowFlares:
                emitted.trainingGuidebotYellowFlares,
            trainingGuidebotYellowFlareParticles:
                emitted.trainingGuidebotYellowFlareParticles
        )
        XCTAssertTrue(retainedPlan.draws.contains {
            $0.model == carrier.model
                && $0.objectHandle == UInt32.max - 1_000
        })
        XCTAssertTrue(retainedPlan.draws.contains {
            $0.texture == particle.texture
                && $0.objectHandle == UInt32.max - 2_000
        })
        XCTAssertTrue(retainedPlan.draws.contains { draw in
            draw.vertices.contains {
                $0.dynamicLight.x > 0
                    || $0.dynamicLight.y > 0
                    || $0.dynamicLight.z > 0
            }
        })

        let player = try XCTUnwrap(eligible.runtimeLevel.objects.first {
            $0.handle == eligible.level.defaultPlayerBinding?.objectHandle
        })
        var attachedObject = try continuationObject(eligible.world)
        attachedObject["frameDuration"] = 0.1
        var attachedState = try XCTUnwrap(
            attachedObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        attachedState["timeUntilNextFlare"] = 3.5
        attachedState["yellowFlareParticles"] = []
        var attachedFlares = try XCTUnwrap(
            attachedState["yellowFlares"] as? [[String: Any]]
        )
        attachedFlares[0]["roomSourceIndex"] = {
            if case let .room(room) = player.location { return room }
            return -1
        }()
        attachedFlares[0]["position"] = [
            "x": player.position.x,
            "y": player.position.y,
            "z": player.position.z,
        ]
        attachedFlares[0]["orientation"] = [
            "right": [
                "x": player.orientation.right.x,
                "y": player.orientation.right.y,
                "z": player.orientation.right.z,
            ],
            "up": [
                "x": player.orientation.up.x,
                "y": player.orientation.up.y,
                "z": player.orientation.up.z,
            ],
            "forward": [
                "x": player.orientation.forward.x,
                "y": player.orientation.forward.y,
                "z": player.orientation.forward.z,
            ],
        ]
        attachedFlares[0]["velocity"] = ["x": 0, "y": 0, "z": 0]
        attachedFlares[0]["stuckObjectHandle"] = player.handle
        attachedFlares[0]["stuckObjectOffset"] = [
            "x": 0, "y": 0, "z": 0,
        ]
        attachedFlares[0]["stuckObjectOrientation"] = [
            "right": ["x": 1, "y": 0, "z": 0],
            "up": ["x": 0, "y": 1, "z": 0],
            "forward": ["x": 0, "y": 0, "z": 1],
        ]
        attachedState["yellowFlares"] = attachedFlares
        attachedObject["trainingRobotGuidebotState"] = attachedState
        let attached = try GameSession(
            level: eligible.level,
            world: (decodeTestWorld(attachedObject)).rebased(onto: eligible.level),
            resumedAtTimestamp: 20.3
        )
        let attachedFrame = attached.update(
            at: 20.4,
            input: .init(forward: 1, yaw: 1)
        )
        let attachedCarrier = try XCTUnwrap(
            attachedFrame.trainingGuidebotYellowFlares.only
        )
        XCTAssertEqual(
            attachedCarrier.position,
            attachedFrame.playerView.camera.position
        )
        XCTAssertNotEqual(attachedCarrier.position, player.position)
        XCTAssertFalse(attachedFrame.trainingOpeningFeedback.contains {
            $0.soundSourceName == "Flare.wav"
        })
        let freshBaseRestore = try GameSession(
            level: level,
            world: attached.world.rebased(onto: level),
            resumedAtTimestamp: 20.5
        )
        let freshBaseFrame = freshBaseRestore.update(
            at: 20.6,
            input: .zero
        )
        XCTAssertEqual(
            freshBaseFrame.trainingGuidebotYellowFlares.count,
            1
        )
        XCTAssertFalse(freshBaseFrame.trainingOpeningFeedback.contains {
            $0.soundSourceName == "Flare.wav"
        })

        var nearWallObject = try continuationObject(
            eligible.world
        )
        nearWallObject["frameDuration"] = 0.01
        var nearWallState = try XCTUnwrap(
            nearWallObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        nearWallState["timeUntilNextFlare"] = 3.5
        nearWallState["yellowFlareParticles"] = []
        var nearWallFlares = try XCTUnwrap(
            nearWallState["yellowFlares"] as? [[String: Any]]
        )
        var nearWallFlare = try XCTUnwrap(nearWallFlares.only)
        let roomCenter = try XCTUnwrap(
            eligible.runtimeLevel.rooms.first { $0.sourceIndex == 1 }
        ).pathPoint
        let forward = carrier.orientation.forward
        let maximumComponent = max(
            abs(forward.x),
            abs(forward.y),
            abs(forward.z)
        )
        let nearWallDistance =
            (500 - carrier.collisionRadius) / maximumComponent - 0.2
        nearWallFlare["position"] = [
            "x": Double(roomCenter.x + forward.x * nearWallDistance),
            "y": Double(roomCenter.y + forward.y * nearWallDistance),
            "z": Double(roomCenter.z + forward.z * nearWallDistance),
        ]
        nearWallFlare["velocity"] = [
            "x": Double(forward.x * 100),
            "y": Double(forward.y * 100),
            "z": Double(forward.z * 100),
        ]
        nearWallFlare["lastParticleDropTime"] =
            nearWallObject["gameTime"]
        nearWallFlares[0] = nearWallFlare
        nearWallState["yellowFlares"] = nearWallFlares
        nearWallObject["trainingRobotGuidebotState"] = nearWallState
        let nearWall = try GameSession(
            level: eligible.level,
            world: (decodeTestWorld(nearWallObject)).rebased(onto: eligible.level),
            resumedAtTimestamp: 21
        )
        let stuckFrame = nearWall.update(at: 21.01, input: .zero)
        XCTAssertEqual(
            try XCTUnwrap(stuckFrame.trainingGuidebotYellowFlares.only)
                .velocity,
            .zero
        )
        XCTAssertTrue(
            stuckFrame.trainingGuidebotYellowFlareParticles.isEmpty
        )
        XCTAssertFalse(stuckFrame.trainingOpeningFeedback.contains {
            $0.soundSourceName == "Flare.wav"
        })

        var exactZeroObject = try continuationObject(nearWall.world)
        exactZeroObject["frameDuration"] = 0.01
        var exactZeroState = try XCTUnwrap(
            exactZeroObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        exactZeroState["timeUntilNextFlare"] = 3.5
        exactZeroState["yellowFlareParticles"] = []
        var exactZeroFlares = try XCTUnwrap(
            exactZeroState["yellowFlares"] as? [[String: Any]]
        )
        exactZeroFlares[0]["lifeRemaining"] = 0.01
        exactZeroFlares[0]["lastParticleDropTime"] =
            exactZeroObject["gameTime"]
        exactZeroState["yellowFlares"] = exactZeroFlares
        exactZeroObject["trainingRobotGuidebotState"] = exactZeroState
        let exactZero = try GameSession(
            level: eligible.level,
            world: (decodeTestWorld(exactZeroObject)).rebased(onto: eligible.level),
            resumedAtTimestamp: 21.5
        )
        let exactZeroFrame = exactZero.update(at: 21.51, input: .zero)
        XCTAssertEqual(
            try XCTUnwrap(exactZeroFrame.trainingGuidebotYellowFlares.only)
                .lifeRemaining,
            0,
            accuracy: 0.000_001
        )

        var expiryObject = try continuationObject(nearWall.world)
        expiryObject["frameDuration"] = 0.01
        var expiryState = try XCTUnwrap(
            expiryObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        expiryState["timeUntilNextFlare"] = 3.5
        expiryState["yellowFlareParticles"] = []
        var expiringFlares = try XCTUnwrap(
            expiryState["yellowFlares"] as? [[String: Any]]
        )
        expiringFlares[0]["position"] = [
            "x": roomCenter.x,
            "y": roomCenter.y,
            "z": roomCenter.z,
        ]
        expiringFlares[0]["velocity"] = ["x": 0, "y": 0, "z": 0]
        expiringFlares[0]["lifeRemaining"] = 0.005
        expiringFlares[0]["lastParticleDropTime"] = 0
        expiryState["yellowFlares"] = expiringFlares
        expiryObject["trainingRobotGuidebotState"] = expiryState
        let expiryInitialRandomState = try randomState(
            in: decodeTestWorld(expiryObject)
        )
        let expiry = try GameSession(
            level: eligible.level,
            world: (decodeTestWorld(expiryObject)).rebased(onto: eligible.level),
            resumedAtTimestamp: 22
        )
        let expiredFrame = expiry.update(at: 22.01, input: .zero)
        XCTAssertTrue(expiredFrame.trainingGuidebotYellowFlares.isEmpty)
        XCTAssertEqual(
            expiredFrame.trainingGuidebotYellowFlareParticles.count,
            1
        )
        let timeoutExplosion = try XCTUnwrap(
            expiredFrame.trainingGuidebotYellowFlareTimeoutExplosions.only
        )
        XCTAssertEqual(timeoutExplosion.texture.sourceName, "FlarePuff")
        XCTAssertEqual(timeoutExplosion.size, 2)
        XCTAssertEqual(timeoutExplosion.lifetime, 0.2)
        XCTAssertEqual(timeoutExplosion.lifeRemaining, 0.19)
        XCTAssertEqual(timeoutExplosion.opacity, 1)
        XCTAssertEqual(timeoutExplosion.position, roomCenter)
        XCTAssertEqual(
            expiredFrame.trainingGuidebotYellowFlareTimeoutSparks
                .map(\.sourceAttemptIndex),
            Array(0..<9)
        )
        XCTAssertEqual(
            expiredFrame.trainingGuidebotYellowFlareTimeoutSparks
                .map(\.sourceObjectSlot),
            [17, 8, 41, 42, 43, 44, 45, 46, 47]
        )
        XCTAssertEqual(
            expiredFrame.trainingGuidebotYellowFlareTimeoutSparks
                .filter(\.receivedControlOnCreationFrame)
                .map(\.sourceAttemptIndex),
            [0, 2, 3, 4, 5, 6, 7, 8]
        )
        XCTAssertEqual(
            expiredFrame.trainingGuidebotYellowFlareTimeoutSparks
                .map(\.lifeRemaining),
            [0.19, 0.2, 0.19, 0.19, 0.19, 0.19, 0.19, 0.19, 0.19]
        )
        XCTAssertTrue(
            expiredFrame.trainingGuidebotYellowFlareTimeoutSparks
                .allSatisfy { $0.lightDistance == 6 }
        )
        let centerSpark = try XCTUnwrap(
            expiredFrame.trainingGuidebotYellowFlareTimeoutSparks.first {
                $0.sourceAttemptIndex == 0
            }
        )
        let centerOrigin = Vector3(
            x: roomCenter.x + centerSpark.orientation.forward.x * 0.05,
            y: roomCenter.y + centerSpark.orientation.forward.y * 0.05,
            z: roomCenter.z + centerSpark.orientation.forward.z * 0.05
        )
        let centerInitialVelocity = Vector3(
            x: centerSpark.orientation.forward.x * 17,
            y: centerSpark.orientation.forward.y * 17,
            z: centerSpark.orientation.forward.z * 17
        )
        let centerExpected = expectedMotion(
            position: centerOrigin,
            velocity: centerInitialVelocity,
            duration: 0.01
        )
        XCTAssertEqual(centerSpark.position.x, centerExpected.position.x)
        XCTAssertEqual(centerSpark.position.y, centerExpected.position.y)
        XCTAssertEqual(centerSpark.position.z, centerExpected.position.z)
        XCTAssertEqual(centerSpark.velocity.x, centerExpected.velocity.x)
        XCTAssertEqual(centerSpark.velocity.y, centerExpected.velocity.y)
        XCTAssertEqual(centerSpark.velocity.z, centerExpected.velocity.z)
        let lowerSlotSpark = try XCTUnwrap(
            expiredFrame.trainingGuidebotYellowFlareTimeoutSparks.first {
                $0.sourceObjectSlot == 8
            }
        )
        XCTAssertEqual(lowerSlotSpark.position, centerOrigin)
        XCTAssertEqual(
            lowerSlotSpark.velocity,
            .init(
                x: lowerSlotSpark.orientation.forward.x * 17,
                y: lowerSlotSpark.orientation.forward.y * 17,
                z: lowerSlotSpark.orientation.forward.z * 17
            )
        )
        XCTAssertEqual(
            expiredFrame.trainingGuidebotYellowFlareTimeoutSparkParticles
                .count,
            8
        )
        let timeoutPlan = try updateMetalWorldPlan(
            try makeMetalWorldPlan(
                level: expiry.runtimeLevel,
                playerView: expiredFrame.playerView
            ),
            level: expiry.level,
            objects: expiry.world.objects,
            roomStates: expiry.world.rooms,
            playerView: expiredFrame.playerView,
            trainingGuidebotYellowFlareParticles:
                expiredFrame.trainingGuidebotYellowFlareParticles,
            trainingGuidebotYellowFlareTimeoutExplosions:
                expiredFrame.trainingGuidebotYellowFlareTimeoutExplosions,
            trainingGuidebotYellowFlareTimeoutSparks:
                expiredFrame.trainingGuidebotYellowFlareTimeoutSparks,
            trainingGuidebotYellowFlareTimeoutSparkParticles:
                expiredFrame
                    .trainingGuidebotYellowFlareTimeoutSparkParticles
        )
        XCTAssertTrue(timeoutPlan.draws.contains {
            $0.texture?.sourceName == "FlarePuff"
                && $0.objectHandle == UInt32.max - 3_000
        })
        XCTAssertEqual(
            timeoutPlan.draws.filter {
                guard let handle = $0.objectHandle else { return false }
                return handle <= UInt32.max - 4_000
                    && handle > UInt32.max - 4_009
            }.count,
            9
        )
        XCTAssertTrue(timeoutPlan.draws.contains { draw in
            guard let handle = draw.objectHandle,
                  handle <= UInt32.max - 4_000,
                  handle > UInt32.max - 4_009 else {
                return false
            }
            return draw.vertices.contains {
                $0.dynamicLight.x > 0
                    || $0.dynamicLight.y > 0
                    || $0.dynamicLight.z > 0
            }
        })
        XCTAssertEqual(
            try randomState(in: expiry.world),
            (0..<54).reduce(expiryInitialRandomState) {
                state, _ in nextState(state)
            }
        )

        var longCreationFrameObject = expiryObject
        longCreationFrameObject["frameDuration"] = 0.21
        let longCreationFrameStart = try decodeTestWorld(longCreationFrameObject)
        let longCreationFrame = try GameSession(
            level: eligible.level,
            world: longCreationFrameStart.rebased(onto: eligible.level),
            resumedAtTimestamp: 22.5
        )
        let longCreationFrameResult = longCreationFrame.update(
            at: 22.71,
            input: .zero
        )
        XCTAssertTrue(
            longCreationFrameResult
                .trainingGuidebotYellowFlareTimeoutExplosions.isEmpty
        )
        XCTAssertEqual(
            longCreationFrameResult
                .trainingGuidebotYellowFlareTimeoutSparks
                .map(\.sourceAttemptIndex),
            [1]
        )
        XCTAssertTrue(
            longCreationFrameResult
                .trainingGuidebotYellowFlareTimeoutSparks
                .allSatisfy { $0.lifeRemaining >= 0 }
        )
        XCTAssertTrue(
            longCreationFrameResult
                .trainingGuidebotYellowFlareTimeoutSparkParticles
                .allSatisfy { $0.lifeRemaining >= 0 }
        )
        XCTAssertEqual(
            try randomState(in: longCreationFrame.world),
            (0..<54).reduce(expiryInitialRandomState) {
                state, _ in nextState(state)
            }
        )
        XCTAssertNoThrow(try GameSession(
            level: eligible.level,
            world: longCreationFrame.world.rebased(onto: eligible.level),
            resumedAtTimestamp: 22.72
        ))
        let postExpiryRandomState = try randomState(
            in: expiry.world
        )
        XCTAssertFalse(expiredFrame.trainingOpeningFeedback.contains {
            $0.soundSourceName == "Flare.wav"
        })
        let expiredRestore = try GameSession(
            level: eligible.level,
            world: expiry.world.rebased(onto: eligible.level),
            resumedAtTimestamp: 23
        )
        let expiredRestoreFrame = expiredRestore.update(
            at: 23.01,
            input: .zero
        )
        XCTAssertTrue(
            expiredRestoreFrame.trainingGuidebotYellowFlares.isEmpty
        )
        XCTAssertEqual(
            expiredRestoreFrame
                .trainingGuidebotYellowFlareTimeoutExplosions.count,
            1
        )
        XCTAssertEqual(
            expiredRestoreFrame
                .trainingGuidebotYellowFlareTimeoutSparks.count,
            9
        )
        XCTAssertEqual(
            expiredRestoreFrame
                .trainingGuidebotYellowFlareTimeoutSparkParticles.count,
            9
        )
        XCTAssertEqual(
            try randomState(in: expiredRestore.world),
            (0..<6).reduce(postExpiryRandomState) {
                state, _ in nextState(state)
            }
        )
        XCTAssertTrue(
            expiredRestoreFrame
                .trainingGuidebotYellowFlareTimeoutSparks
                .allSatisfy { $0.lightDistance == 6 }
        )
        let restoredCenterSpark = try XCTUnwrap(
            expiredRestoreFrame
                .trainingGuidebotYellowFlareTimeoutSparks.first {
                    $0.sourceAttemptIndex == 0
                }
        )
        let restoredCenterExpected = expectedMotion(
            position: centerSpark.position,
            velocity: centerSpark.velocity,
            duration: 0.01
        )
        XCTAssertEqual(
            restoredCenterSpark.position.x,
            restoredCenterExpected.position.x
        )
        XCTAssertEqual(
            restoredCenterSpark.position.y,
            restoredCenterExpected.position.y
        )
        XCTAssertEqual(
            restoredCenterSpark.position.z,
            restoredCenterExpected.position.z
        )
        XCTAssertEqual(
            restoredCenterSpark.velocity.x,
            restoredCenterExpected.velocity.x
        )
        XCTAssertEqual(
            restoredCenterSpark.velocity.y,
            restoredCenterExpected.velocity.y
        )
        XCTAssertEqual(
            restoredCenterSpark.velocity.z,
            restoredCenterExpected.velocity.z
        )
        XCTAssertFalse(expiredRestoreFrame.trainingOpeningFeedback.contains {
            $0.soundSourceName == "Flare.wav"
        })
        let boundedTimeoutRandomState = try randomState(
            in: expiredRestore.world
        )
        let boundedTimeoutFrame = expiredRestore.update(
            at: 23.02,
            input: .zero
        )
        XCTAssertEqual(
            try XCTUnwrap(
                boundedTimeoutFrame
                    .trainingGuidebotYellowFlareTimeoutExplosions.only
            ).lifeRemaining,
            0.17,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            try XCTUnwrap(
                boundedTimeoutFrame
                    .trainingGuidebotYellowFlareTimeoutSparks.first {
                        $0.sourceAttemptIndex == 0
                    }
            ).lifeRemaining,
            0.17,
            accuracy: 0.000_001
        )
        XCTAssertNotEqual(
            try XCTUnwrap(
                boundedTimeoutFrame
                    .trainingGuidebotYellowFlareTimeoutSparkParticles.first
            ).position,
            try XCTUnwrap(
                expiredRestoreFrame
                    .trainingGuidebotYellowFlareTimeoutSparkParticles.first
            ).position
        )
        XCTAssertEqual(
            try randomState(in: expiredRestore.world),
            boundedTimeoutRandomState
        )

        var finalNegativeObject = try continuationObject(
            expiry.world
        )
        finalNegativeObject["frameDuration"] = 0.01
        var finalNegativeState = try XCTUnwrap(
            finalNegativeObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        finalNegativeState["timeUntilNextFlare"] = 3.5
        var finalNegativeSparks = try XCTUnwrap(
            finalNegativeState["yellowFlareTimeoutSparks"]
                as? [[String: Any]]
        )
        let finalNegativeGameTime = try XCTUnwrap(
            (finalNegativeObject["gameTime"] as? NSNumber)?.floatValue
        )
        for index in finalNegativeSparks.indices {
            if finalNegativeSparks[index]["receivedControlOnCreationFrame"]
                as? Bool == true {
                finalNegativeSparks[index]["lifeRemaining"] = 0.005
                finalNegativeSparks[index]["lastParticleDropTime"] =
                    finalNegativeGameTime
            } else {
                finalNegativeSparks[index]["lifeRemaining"] = 0.1
            }
        }
        let finalNegativeAttemptIndex = try XCTUnwrap(
            finalNegativeSparks.firstIndex {
                $0["sourceAttemptIndex"] as? Int == 0
            }
        )
        let survivingAttemptIndex = try XCTUnwrap(
            finalNegativeSparks.firstIndex {
                $0["sourceAttemptIndex"] as? Int == 1
            }
        )
        finalNegativeSparks[finalNegativeAttemptIndex][
            "lastParticleDropTime"
        ] = 0
        finalNegativeSparks[survivingAttemptIndex][
            "lastParticleDropTime"
        ] = finalNegativeGameTime
        finalNegativeState["yellowFlareTimeoutSparks"] =
            finalNegativeSparks
        finalNegativeObject["trainingRobotGuidebotState"] =
            finalNegativeState
        let finalNegativeStart = try decodeTestWorld(finalNegativeObject)
        let finalNegativeRandomState = try randomState(
            in: finalNegativeStart
        )
        let finalNegative = try GameSession(
            level: eligible.level,
            world: finalNegativeStart.rebased(onto: eligible.level),
            resumedAtTimestamp: 24
        )
        let finalNegativeFrame = finalNegative.update(
            at: 24.01,
            input: .zero
        )
        XCTAssertEqual(
            finalNegativeFrame.trainingGuidebotYellowFlareTimeoutSparks
                .map(\.sourceAttemptIndex),
            [1]
        )
        XCTAssertEqual(
            finalNegativeFrame
                .trainingGuidebotYellowFlareTimeoutSparkParticles.count,
            9
        )
        XCTAssertEqual(
            try randomState(in: finalNegative.world),
            (0..<6).reduce(finalNegativeRandomState) {
                state, _ in nextState(state)
            }
        )

        var exactZeroChildObject = try continuationObject(
            expiry.world
        )
        exactZeroChildObject["frameDuration"] = 0.01
        var exactZeroChildState = try XCTUnwrap(
            exactZeroChildObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        var exactZeroChildSparks = try XCTUnwrap(
            exactZeroChildState["yellowFlareTimeoutSparks"]
                as? [[String: Any]]
        )
        for index in exactZeroChildSparks.indices
        where exactZeroChildSparks[index][
            "receivedControlOnCreationFrame"
        ] as? Bool == true {
            exactZeroChildSparks[index]["lifeRemaining"] = 0.01
            exactZeroChildSparks[index]["lastParticleDropTime"] =
                finalNegativeGameTime
        }
        let exactZeroChildStartPosition = try XCTUnwrap(
            exactZeroChildSparks.first {
                $0["sourceAttemptIndex"] as? Int == 0
            }?["position"] as? [String: NSNumber]
        )
        exactZeroChildState["yellowFlareTimeoutSparks"] =
            exactZeroChildSparks
        exactZeroChildObject["trainingRobotGuidebotState"] =
            exactZeroChildState
        let exactZeroChild = try GameSession(
            level: eligible.level,
            world: (decodeTestWorld(exactZeroChildObject)).rebased(onto: eligible.level),
            resumedAtTimestamp: 24.5
        )
        let exactZeroChildFrame = exactZeroChild.update(
            at: 24.51,
            input: .zero
        )
        let exactZeroControlledChild = try XCTUnwrap(
            exactZeroChildFrame
                .trainingGuidebotYellowFlareTimeoutSparks.first {
                    $0.sourceAttemptIndex == 0
                }
        )
        XCTAssertEqual(
            exactZeroControlledChild.lifeRemaining,
            0,
            accuracy: 0.000_001
        )
        XCTAssertNotEqual(
            exactZeroControlledChild.position.y,
            try XCTUnwrap(
                exactZeroChildStartPosition["y"]?.floatValue
            )
        )
        XCTAssertEqual(exactZeroControlledChild.lightDistance, 6)

        var exactZeroVisualObject = try continuationObject(
            expiry.world
        )
        exactZeroVisualObject["frameDuration"] = 0.01
        var exactZeroVisualState = try XCTUnwrap(
            exactZeroVisualObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        var exactZeroVisualParticles = try XCTUnwrap(
            exactZeroVisualState["yellowFlareTimeoutSparkParticles"]
                as? [[String: Any]]
        )
        exactZeroVisualParticles[0]["lifeRemaining"] = 0.01
        exactZeroVisualState["yellowFlareTimeoutSparkParticles"] =
            exactZeroVisualParticles
        exactZeroVisualObject["trainingRobotGuidebotState"] =
            exactZeroVisualState
        let exactZeroVisual = try GameSession(
            level: eligible.level,
            world: (decodeTestWorld(exactZeroVisualObject)).rebased(onto: eligible.level),
            resumedAtTimestamp: 25
        )
        let exactZeroVisualFrame = exactZeroVisual.update(
            at: 25.01,
            input: .zero
        )
        XCTAssertTrue(
            exactZeroVisualFrame
                .trainingGuidebotYellowFlareTimeoutSparkParticles
                .contains { abs($0.lifeRemaining) < 0.000_001 }
        )

        func capacityContinuation(
            count: Int
        ) throws -> GameWorld {
            var object = try continuationObject(expiry.world)
            object["frameDuration"] = 0.01
            var state = try XCTUnwrap(
                object["trainingRobotGuidebotState"] as? [String: Any]
            )
            var sparks = try XCTUnwrap(
                state["yellowFlareTimeoutSparks"] as? [[String: Any]]
            )
            for index in sparks.indices {
                sparks[index]["lastParticleDropTime"] = 0
            }
            let particles = try XCTUnwrap(
                state["yellowFlareTimeoutSparkParticles"]
                    as? [[String: Any]]
            )
            state["yellowFlareTimeoutSparks"] = sparks
            state["yellowFlareTimeoutSparkParticles"] =
                (0..<count).map { particles[$0 % particles.count] }
            object["trainingRobotGuidebotState"] = state
            return try decodeTestWorld(object)
        }
        let fullCapacityStart = try capacityContinuation(count: 54)
        let fullCapacityRandomState = try randomState(
            in: fullCapacityStart
        )
        let fullCapacity = try GameSession(
            level: eligible.level,
            world: fullCapacityStart.rebased(onto: eligible.level),
            resumedAtTimestamp: 26
        )
        let fullCapacityFrame = fullCapacity.update(
            at: 26.01,
            input: .zero
        )
        XCTAssertEqual(
            fullCapacityFrame
                .trainingGuidebotYellowFlareTimeoutSparkParticles.count,
            54
        )
        XCTAssertEqual(
            try randomState(in: fullCapacity.world),
            fullCapacityRandomState
        )
        let oneFreeStart = try capacityContinuation(count: 53)
        let oneFreeRandomState = try randomState(in: oneFreeStart)
        let oneFree = try GameSession(
            level: eligible.level,
            world: oneFreeStart.rebased(onto: eligible.level),
            resumedAtTimestamp: 26.5
        )
        XCTAssertEqual(
            oneFree.update(at: 26.51, input: .zero)
                .trainingGuidebotYellowFlareTimeoutSparkParticles.count,
            54
        )
        XCTAssertEqual(
            try randomState(in: oneFree.world),
            (0..<6).reduce(oneFreeRandomState) {
                state, _ in nextState(state)
            }
        )

        let timeoutDefinition = try XCTUnwrap(
            eligible.level.trainingRobotGuidebotChain?
                .yellowFlare?.timeout
        )
        let animationFrames = try XCTUnwrap(
            timeoutDefinition.childAnimationFrames
        )
        let sourceFrameTime = try XCTUnwrap(
            timeoutDefinition.childSourceFrameTime
        )
        XCTAssertEqual(animationFrames.count, 6)
        XCTAssertTrue(
            expiredFrame.trainingGuidebotYellowFlareTimeoutSparks
                .allSatisfy {
                    $0.texture
                        == animationFrames[
                            Int(expiredFrame.systemsGameTime / sourceFrameTime)
                                % animationFrames.count
                        ]
                }
        )
        XCTAssertTrue(
            expiredFrame
                .trainingGuidebotYellowFlareTimeoutSparkParticles
                .allSatisfy {
                    $0.texture == animationFrames[0] && $0.opacity == 1
                }
        )

        var agedVisualObject = try continuationObject(
            expiry.world
        )
        agedVisualObject["frameDuration"] = 0.01
        let agedVisualGameTime = try XCTUnwrap(
            (agedVisualObject["gameTime"] as? NSNumber)?.floatValue
        )
        var agedVisualState = try XCTUnwrap(
            agedVisualObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        var agedVisualParticles = try XCTUnwrap(
            agedVisualState["yellowFlareTimeoutSparkParticles"]
                as? [[String: Any]]
        )
        let testedNormalizedAges = animationFrames.indices.map {
            (Float($0) + 0.5) / Float(animationFrames.count)
        }
        for index in animationFrames.indices {
            let normalizedAge = testedNormalizedAges[index]
            agedVisualParticles[index]["lifetime"] = 0.3
            agedVisualParticles[index]["lifeRemaining"] =
                0.3 * (1 - normalizedAge)
            agedVisualParticles[index]["creationTime"] =
                agedVisualGameTime - 0.3 * normalizedAge
        }
        agedVisualState["yellowFlareTimeoutSparkParticles"] =
            agedVisualParticles
        agedVisualObject["trainingRobotGuidebotState"] =
            agedVisualState
        let agedVisual = try GameSession(
            level: eligible.level,
            world: (decodeTestWorld(agedVisualObject)).rebased(onto: eligible.level),
            resumedAtTimestamp: 27
        )
        let agedVisualFrame = agedVisual.update(
            at: 27.01,
            input: .zero
        )
        let presentedAgedParticles = Array(
            agedVisualFrame
                .trainingGuidebotYellowFlareTimeoutSparkParticles
                .prefix(animationFrames.count)
        )
        XCTAssertEqual(
            presentedAgedParticles.map(\.texture),
            animationFrames
        )
        let finalTestedNormalizedAge = try XCTUnwrap(
            testedNormalizedAges.last
        )
        XCTAssertEqual(
            try XCTUnwrap(presentedAgedParticles.last).opacity,
            2 * (1 - finalTestedNormalizedAge),
            accuracy: 0.000_1
        )

        let quiescing = try GameSession(
            level: eligible.level,
            world: expiry.world.rebased(onto: eligible.level),
            resumedAtTimestamp: 28
        )
        var quiescentFrame: PlayerSimulationFrame?
        for frameIndex in 1...100 {
            let candidate = quiescing.update(
                at: 28 + Double(frameIndex) * 0.01,
                input: .zero
            )
            if candidate
                .trainingGuidebotYellowFlareTimeoutExplosions.isEmpty,
               candidate.trainingGuidebotYellowFlareTimeoutSparks.isEmpty,
               candidate
                .trainingGuidebotYellowFlareTimeoutSparkParticles.isEmpty {
                quiescentFrame = candidate
                break
            }
        }
        let terminalFrame = try XCTUnwrap(quiescentFrame)
        let terminalObject = try continuationObject(
            quiescing.world
        )
        let terminalState = try XCTUnwrap(
            terminalObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        XCTAssertEqual(
            terminalState["yellowFlareTimeoutReachedFollowingFrame"]
                as? Bool,
            true
        )
        let terminalRestore = try GameSession(
            level: eligible.level,
            world: quiescing.world.rebased(onto: eligible.level),
            resumedAtTimestamp: 30
        )
        let terminalRestoreFrame = terminalRestore.update(
            at: 30.01,
            input: .zero
        )
        XCTAssertTrue(
            terminalRestoreFrame
                .trainingGuidebotYellowFlareTimeoutExplosions.isEmpty
        )
        XCTAssertTrue(
            terminalRestoreFrame
                .trainingGuidebotYellowFlareTimeoutSparks.isEmpty
        )
        XCTAssertTrue(
            terminalRestoreFrame
                .trainingGuidebotYellowFlareTimeoutSparkParticles.isEmpty
        )
        let terminalPlan = try updateMetalWorldPlan(
            timeoutPlan,
            level: eligible.level,
            objects: eligible.world.objects,
            roomStates: eligible.world.rooms,
            playerView: terminalFrame.playerView,
            trainingGuidebotYellowFlareParticles:
                terminalFrame.trainingGuidebotYellowFlareParticles,
            trainingGuidebotYellowFlareTimeoutExplosions:
                terminalFrame.trainingGuidebotYellowFlareTimeoutExplosions,
            trainingGuidebotYellowFlareTimeoutSparks:
                terminalFrame.trainingGuidebotYellowFlareTimeoutSparks,
            trainingGuidebotYellowFlareTimeoutSparkParticles:
                terminalFrame
                    .trainingGuidebotYellowFlareTimeoutSparkParticles
        )
        XCTAssertFalse(terminalPlan.draws.contains { draw in
            guard let handle = draw.objectHandle else { return false }
            return handle == UInt32.max - 3_000
                || (handle <= UInt32.max - 4_000
                    && handle > UInt32.max - 4_009)
                || (handle <= UInt32.max - 5_000
                    && handle > UInt32.max - 5_054)
        })

        var laterParentObject = try continuationObject(
            quiescing.world
        )
        laterParentObject["frameDuration"] = 0.01
        var laterParentState = try XCTUnwrap(
            laterParentObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        laterParentState["timeUntilNextFlare"] = 0.005
        laterParentObject["trainingRobotGuidebotState"] =
            laterParentState
        let laterParent = try GameSession(
            level: eligible.level,
            world: (decodeTestWorld(laterParentObject)).rebased(onto: eligible.level),
            resumedAtTimestamp: 31
        )
        let laterParentFrame = laterParent.update(
            at: 31.01,
            input: .zero
        )
        XCTAssertEqual(laterParentFrame.trainingGuidebotYellowFlares.count, 1)
        var laterExpiryObject = try continuationObject(
            laterParent.world
        )
        laterExpiryObject["frameDuration"] = 0.01
        var laterExpiryState = try XCTUnwrap(
            laterExpiryObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        var laterFlares = try XCTUnwrap(
            laterExpiryState["yellowFlares"] as? [[String: Any]]
        )
        laterFlares[0]["lifeRemaining"] = 0.005
        laterFlares[0]["lastParticleDropTime"] =
            laterExpiryObject["gameTime"]
        laterExpiryState["yellowFlares"] = laterFlares
        laterExpiryObject["trainingRobotGuidebotState"] =
            laterExpiryState
        let laterExpiry = try GameSession(
            level: eligible.level,
            world: (decodeTestWorld(laterExpiryObject)).rebased(onto: eligible.level),
            resumedAtTimestamp: 31.1
        )
        let laterExpiryFrame = laterExpiry.update(
            at: 31.11,
            input: .zero
        )
        XCTAssertTrue(laterExpiryFrame.trainingGuidebotYellowFlares.isEmpty)
        XCTAssertTrue(
            laterExpiryFrame
                .trainingGuidebotYellowFlareTimeoutExplosions.isEmpty
        )
        XCTAssertTrue(
            laterExpiryFrame
                .trainingGuidebotYellowFlareTimeoutSparks.isEmpty
        )
        XCTAssertTrue(
            laterExpiryFrame
                .trainingGuidebotYellowFlareTimeoutSparkParticles.isEmpty
        )

        var missingVisualAgeObject = try continuationObject(
            expiry.world
        )
        var missingVisualAgeState = try XCTUnwrap(
            missingVisualAgeObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        var missingVisualAgeParticles = try XCTUnwrap(
            missingVisualAgeState[
                "yellowFlareTimeoutSparkParticles"
            ] as? [[String: Any]]
        )
        missingVisualAgeParticles[0].removeValue(forKey: "creationTime")
        missingVisualAgeState[
            "yellowFlareTimeoutSparkParticles"
        ] = missingVisualAgeParticles
        missingVisualAgeObject["trainingRobotGuidebotState"] =
            missingVisualAgeState

        var missingTimeoutObject = try continuationObject(
            expiry.world
        )
        var missingTimeoutState = try XCTUnwrap(
            missingTimeoutObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        var missingSparks = try XCTUnwrap(
            missingTimeoutState["yellowFlareTimeoutSparks"]
                as? [[String: Any]]
        )
        missingSparks.removeLast()
        missingTimeoutState["yellowFlareTimeoutSparks"] =
            missingSparks
        missingTimeoutObject["trainingRobotGuidebotState"] =
            missingTimeoutState

        var legacyTimeoutObject = try continuationObject(
            expiry.world
        )
        var legacyTimeoutState = try XCTUnwrap(
            legacyTimeoutObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        legacyTimeoutState.removeValue(
            forKey: "yellowFlareTimeoutExplosions"
        )
        legacyTimeoutState.removeValue(
            forKey: "yellowFlareTimeoutSparks"
        )
        legacyTimeoutState.removeValue(
            forKey: "yellowFlareTimeoutSparkParticles"
        )
        legacyTimeoutState.removeValue(
            forKey: "yellowFlareTimeoutReachedFollowingFrame"
        )
        legacyTimeoutObject["trainingRobotGuidebotState"] =
            legacyTimeoutState
        let legacyTimeoutRestore = try GameSession(
            level: eligible.level,
            world: (decodeTestWorld(legacyTimeoutObject)).rebased(onto: eligible.level),
            resumedAtTimestamp: 23
        )
        let legacyTimeoutFrame = legacyTimeoutRestore.update(
            at: 23.01,
            input: .zero
        )
        XCTAssertTrue(
            legacyTimeoutFrame
                .trainingGuidebotYellowFlareTimeoutExplosions.isEmpty
        )
        XCTAssertTrue(
            legacyTimeoutFrame
                .trainingGuidebotYellowFlareTimeoutSparks.isEmpty
        )

        var parentOnlyLevelObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(eligible.level)
            ) as? [String: Any]
        )
        var parentOnlyChain = try XCTUnwrap(
            parentOnlyLevelObject["trainingRobotGuidebotChain"]
                as? [String: Any]
        )
        var parentOnlyFlare = try XCTUnwrap(
            parentOnlyChain["yellowFlare"] as? [String: Any]
        )
        parentOnlyFlare.removeValue(forKey: "timeout")
        parentOnlyChain["yellowFlare"] = parentOnlyFlare
        parentOnlyLevelObject["trainingRobotGuidebotChain"] =
            parentOnlyChain
        let parentOnlyLevel = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(
                withJSONObject: parentOnlyLevelObject
            )
        )
        var parentOnlyObject = expiryObject
        var parentOnlyState = try XCTUnwrap(
            parentOnlyObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        parentOnlyState.removeValue(
            forKey: "yellowFlareTimeoutExplosions"
        )
        parentOnlyState.removeValue(
            forKey: "yellowFlareTimeoutSparks"
        )
        parentOnlyState.removeValue(
            forKey: "yellowFlareTimeoutSparkParticles"
        )
        parentOnlyState.removeValue(
            forKey: "yellowFlareTimeoutReachedFollowingFrame"
        )
        parentOnlyObject["trainingRobotGuidebotState"] =
            parentOnlyState
        let parentOnlyRestore = try GameSession(
            level: parentOnlyLevel,
            world: (decodeTestWorld(parentOnlyObject)).rebased(onto: parentOnlyLevel),
            resumedAtTimestamp: 24
        )
        let parentOnlyFrame = parentOnlyRestore.update(
            at: 24.01,
            input: .zero
        )
        XCTAssertTrue(parentOnlyFrame.trainingGuidebotYellowFlares.isEmpty)
        XCTAssertTrue(
            parentOnlyFrame
                .trainingGuidebotYellowFlareTimeoutExplosions.isEmpty
        )
        XCTAssertTrue(
            parentOnlyFrame
                .trainingGuidebotYellowFlareTimeoutSparks.isEmpty
        )
        XCTAssertTrue(
            parentOnlyFrame
                .trainingGuidebotYellowFlareTimeoutSparkParticles.isEmpty
        )

        var oneFrameLevelObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(eligible.level)
            ) as? [String: Any]
        )
        var oneFrameChain = try XCTUnwrap(
            oneFrameLevelObject["trainingRobotGuidebotChain"]
                as? [String: Any]
        )
        var oneFrameFlare = try XCTUnwrap(
            oneFrameChain["yellowFlare"] as? [String: Any]
        )
        var oneFrameTimeout = try XCTUnwrap(
            oneFrameFlare["timeout"] as? [String: Any]
        )
        oneFrameTimeout.removeValue(forKey: "childAnimationFrames")
        oneFrameTimeout.removeValue(forKey: "childSourceFrameTime")
        oneFrameFlare["timeout"] = oneFrameTimeout
        oneFrameChain["yellowFlare"] = oneFrameFlare
        oneFrameLevelObject["trainingRobotGuidebotChain"] =
            oneFrameChain
        var oneFrameMaterials = try XCTUnwrap(
            oneFrameLevelObject["presentationMaterials"]
                as? [[String: Any]]
        )
        oneFrameMaterials.removeAll { material in
            guard let texture = material["texture"] as? [String: Any],
                  let sourceName = texture["sourceName"] as? String else {
                return false
            }
            return sourceName.hasPrefix("yellowspark.oaf frame ")
        }
        oneFrameLevelObject["presentationMaterials"] =
            oneFrameMaterials
        var oneFrameManifest = try XCTUnwrap(
            oneFrameLevelObject["dependencyManifest"]
                as? [String: Any]
        )
        var oneFrameDependencies = try XCTUnwrap(
            oneFrameManifest["current"] as? [[String: Any]]
        )
        oneFrameDependencies.removeAll { dependency in
            guard let source = dependency["source"] as? [String: Any],
                  let sourceName = source["sourceName"] as? String else {
                return false
            }
            return sourceName.hasPrefix("yellowspark.oaf frame ")
        }
        oneFrameManifest["current"] = oneFrameDependencies
        oneFrameLevelObject["dependencyManifest"] = oneFrameManifest
        let oneFrameLevel = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(
                withJSONObject: oneFrameLevelObject
            )
        )
        let oneFrameTimeoutDefinition = try XCTUnwrap(
            oneFrameLevel.trainingRobotGuidebotChain?
                .yellowFlare?.timeout
        )
        XCTAssertTrue(oneFrameTimeoutDefinition.hasCoherentChildAnimationBinding)
        XCTAssertNoThrow(
            try validateTrainingGuidebotYellowFlareAnimationBinding(
                timeout: oneFrameTimeoutDefinition,
                materials: oneFrameLevel.presentationMaterials,
                dependencies: oneFrameLevel.dependencyManifest.current
            )
        )
        let oneFrameRestore = try GameSession(
            level: oneFrameLevel,
            world: expiry.world.rebased(onto: oneFrameLevel),
            resumedAtTimestamp: 32
        )
        let oneFrame = oneFrameRestore.update(
            at: 32.01,
            input: .zero
        )
        XCTAssertTrue(
            oneFrame.trainingGuidebotYellowFlareTimeoutSparks
                .allSatisfy { $0.texture.sourceName == "yellowspark" }
        )
        XCTAssertTrue(
            oneFrame.trainingGuidebotYellowFlareTimeoutSparkParticles
                .allSatisfy { $0.texture.sourceName == "yellowspark" }
        )

        var incompleteBindingObject = oneFrameLevelObject
        var incompleteBindingChain = try XCTUnwrap(
            incompleteBindingObject["trainingRobotGuidebotChain"]
                as? [String: Any]
        )
        var incompleteBindingFlare = try XCTUnwrap(
            incompleteBindingChain["yellowFlare"] as? [String: Any]
        )
        var incompleteBindingTimeout = try XCTUnwrap(
            incompleteBindingFlare["timeout"] as? [String: Any]
        )
        incompleteBindingTimeout["childAnimationFrames"] =
            animationFrames.map {
                [
                    "storedIndex": $0.storedIndex,
                    "sourceName": $0.sourceName,
                ]
            }
        incompleteBindingFlare["timeout"] = incompleteBindingTimeout
        incompleteBindingChain["yellowFlare"] = incompleteBindingFlare
        incompleteBindingObject["trainingRobotGuidebotChain"] =
            incompleteBindingChain
        let incompleteBinding = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(
                withJSONObject: incompleteBindingObject
            )
        )
        XCTAssertFalse(
            try XCTUnwrap(
                incompleteBinding.trainingRobotGuidebotChain?
                    .yellowFlare?.timeout
            ).hasCoherentChildAnimationBinding
        )
        XCTAssertThrowsError(
            try validateTrainingGuidebotYellowFlareAnimationBinding(
                timeout: incompleteBinding.trainingRobotGuidebotChain?
                    .yellowFlare?.timeout,
                materials: incompleteBinding.presentationMaterials,
                dependencies: incompleteBinding.dependencyManifest.current
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency(
                    "Training Guidebot Yellow flare animation binding"
                )
            )
        }

        var wrongCadenceObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(eligible.level)
            ) as? [String: Any]
        )
        var wrongCadenceChain = try XCTUnwrap(
            wrongCadenceObject["trainingRobotGuidebotChain"]
                as? [String: Any]
        )
        var wrongCadenceFlare = try XCTUnwrap(
            wrongCadenceChain["yellowFlare"] as? [String: Any]
        )
        var wrongCadenceTimeout = try XCTUnwrap(
            wrongCadenceFlare["timeout"] as? [String: Any]
        )
        wrongCadenceTimeout["childSourceFrameTime"] = 0.071
        wrongCadenceFlare["timeout"] = wrongCadenceTimeout
        wrongCadenceChain["yellowFlare"] = wrongCadenceFlare
        wrongCadenceObject["trainingRobotGuidebotChain"] =
            wrongCadenceChain
        let wrongCadenceLevel = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(withJSONObject: wrongCadenceObject)
        )
        let wrongCadenceDefinition = try XCTUnwrap(
            wrongCadenceLevel.trainingRobotGuidebotChain?
                .yellowFlare?.timeout
        )
        XCTAssertFalse(wrongCadenceDefinition.hasCoherentChildAnimationBinding)
        XCTAssertThrowsError(
            try validateTrainingGuidebotYellowFlareAnimationBinding(
                timeout: wrongCadenceDefinition,
                materials: wrongCadenceLevel.presentationMaterials,
                dependencies: wrongCadenceLevel.dependencyManifest.current
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency(
                    "Training Guidebot Yellow flare animation binding"
                )
            )
        }

        var compatibleLevelObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(level)
            ) as? [String: Any]
        )
        var compatibleChain = try XCTUnwrap(
            compatibleLevelObject["trainingRobotGuidebotChain"]
                as? [String: Any]
        )
        compatibleChain.removeValue(forKey: "yellowFlare")
        compatibleLevelObject["trainingRobotGuidebotChain"] = compatibleChain
        let compatibleLevel = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(withJSONObject: compatibleLevelObject)
        )
        let compatibleSeed = GameSession(
            level: compatibleLevel,
            presentationReadyTimestamp: 0
        )
        _ = compatibleSeed.update(
            at: 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        var compatibleObject = try continuationObject(
            compatibleSeed.world
        )
        compatibleObject["authoritativeRandomState"] = NSNumber(
            value: initialRandomState
        )
        var compatibleState = try XCTUnwrap(
            compatibleObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        compatibleState["guidebotMode"] = "ambient"
        compatibleState["guidebotModeTime"] = 0.1
        compatibleState["nextAmbientTime"] = 100.0
        compatibleState["timeUntilNextFlare"] = 0.05
        compatibleState["nextPowerupCheckTime"] = 100.0
        compatibleObject["trainingRobotGuidebotState"] = compatibleState
        let compatible = try GameSession(
            level: compatibleLevel,
            world: (decodeTestWorld(compatibleObject)).rebased(onto: compatibleLevel),
            resumedAtTimestamp: 30
        )
        let compatibleFrame = compatible.update(at: 30.1, input: .zero)
        XCTAssertEqual(
            try randomState(in: compatible.world),
            nextState(initialRandomState)
        )
        XCTAssertTrue(compatibleFrame.trainingGuidebotYellowFlares.isEmpty)
        XCTAssertTrue(
            compatibleFrame.trainingGuidebotYellowFlareParticles.isEmpty
        )
        XCTAssertFalse(compatibleFrame.trainingOpeningFeedback.contains {
            $0.soundSourceName == "Flare.wav"
        })
    }
}
