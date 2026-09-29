import XCTest

// GameSave continuation contract, structural load validation, and durable
// writes (architecture.md section 7).
final class GameSaveTests: XCTestCase {
    func testSavedWorldAdvancesIdenticallyAfterMidOpeningLesson() throws {
        try assertSaveContinuation(
            level: makeTrainingMovingTargetHandoffLevel(),
            warmupFrames: 18,
            followFrames: 40,
            atSave: { session in
                XCTAssertEqual(
                    session.world.trainingOpeningState?.welcomeWasPresented,
                    true
                )
            }
        )
    }

    func testSavedWorldAdvancesIdenticallyAfterGuidebotRelease() throws {
        let level = makeTrainingCameraMonitorLevel()
        let chain = try XCTUnwrap(level.trainingRobotGuidebotChain)
        try assertSaveContinuation(
            level: level,
            prepare: { session in
                session.destroyTrainingRobot(
                    handle: chain.destroyRobotObjectHandle
                )
            },
            firstInput: .init(deploysTrainingGuidebot: true),
            warmupFrames: 12,
            followFrames: 60,
            atSave: { session in
                XCTAssertEqual(
                    session.world.trainingRobotGuidebotState?
                        .guidebotIsDeployed,
                    true
                )
                XCTAssertNotNil(
                    session.world.objects[
                        ObjectHandle(chain.guidebotObjectHandle)
                    ]
                )
            }
        )
    }

    func testSavedWorldAdvancesIdenticallyAfterRobotDeath() throws {
        let level = makeTrainingRASBot1DeathLevel()
        let chain = try XCTUnwrap(level.trainingRASBot1DeathChain)
        let placedCount = ObjectTable(level: level).count
        try assertSaveContinuation(
            level: level,
            prepare: { session in
                session.destroyTrainingRASBot1(handle: chain.robotObjectHandle)
            },
            warmupFrames: 6,
            followFrames: 30,
            atSave: { session in
                XCTAssertNil(
                    session.world.objects[ObjectHandle(chain.robotObjectHandle)]
                )
                XCTAssertEqual(session.world.objects.count, placedCount - 1)
                XCTAssertEqual(
                    session.world.trainingRASBot1DeathState?.wasDestroyed,
                    true
                )
            }
        )
    }

    func testInterruptedWriteLeavesThePriorSaveReadable() throws {
        let root = try makeTemporarySaveRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let profileID = UUID()
        let package = makePackageReference()
        let level = makeTrainingRASBot1DeathLevel()
        let session = GameSession(level: level, presentationReadyTimestamp: 0)
        _ = session.update(at: 0.1, input: .zero)
        let first = session.world
        let saveFile = GameSaveFile(rootURL: root)
        try saveFile.save(
            profileID: profileID,
            package: package,
            world: first,
            level: level
        )
        let saveURL = saveFile.quicksaveURL(profileID: profileID)
        let firstData = try Data(contentsOf: saveURL)

        // A process that stops after writing part of the temporary file and
        // before the replace leaves only a stray temporary file.
        _ = session.update(at: 0.2, input: .init(forward: 1))
        let second = session.world
        XCTAssertNotEqual(second, first)
        let secondData = try canonicalJSONData(GameSave(
            profileID: profileID,
            package: package,
            world: second
        ))
        let strayURL = saveURL.deletingLastPathComponent().appending(
            path: ".quicksave.json.\(UUID().uuidString).tmp"
        )
        try secondData.prefix(secondData.count / 2).write(to: strayURL)
        XCTAssertEqual(try Data(contentsOf: saveURL), firstData)
        XCTAssertEqual(
            try saveFile.load(
                profileID: profileID,
                package: package,
                baseLevel: level,
                resumedAtTimestamp: 10
            ).world,
            first
        )

        // A save refused before the write leaves the prior save and no
        // temporary file of its own.
        var invalid = second
        invalid.gameTime = .nan
        XCTAssertThrowsError(try saveFile.save(
            profileID: profileID,
            package: package,
            world: invalid,
            level: level
        )) {
            XCTAssertEqual(
                $0 as? GameSaveError,
                .invalidWorld(.nonFiniteValue("gameTime"))
            )
        }
        XCTAssertEqual(try Data(contentsOf: saveURL), firstData)

        // A complete save replaces the prior one atomically.
        try saveFile.save(
            profileID: profileID,
            package: package,
            world: second,
            level: level
        )
        XCTAssertEqual(try Data(contentsOf: saveURL), secondData)
        let remaining = try FileManager.default.contentsOfDirectory(
            atPath: saveURL.deletingLastPathComponent().path
        ).sorted()
        XCTAssertEqual(
            remaining,
            [strayURL.lastPathComponent, "quicksave.json"].sorted()
        )
    }

    func testLoadValidationRejectsStructurallyInconsistentWorlds() throws {
        let level = makeTrainingRASBot1DeathLevel()
        let binding = try XCTUnwrap(level.defaultPlayerBinding)
        let world = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        ).world
        XCTAssertNoThrow(try world.validate(against: level))

        func assertRejected(
            _ expected: GameWorldValidationError,
            _ candidate: GameWorld,
            line: UInt = #line
        ) {
            XCTAssertThrowsError(
                try GameSession(
                    level: level,
                    world: candidate,
                    resumedAtTimestamp: 0
                ),
                line: line
            ) {
                XCTAssertEqual(
                    $0 as? GameSessionRestoreError,
                    .invalidWorld(expected),
                    line: line
                )
            }
        }
        func decoded(
            _ mutate: (inout [String: Any]) throws -> Void
        ) throws -> GameWorld {
            var object = try XCTUnwrap(
                JSONSerialization.jsonObject(
                    with: JSONEncoder().encode(world)
                ) as? [String: Any]
            )
            try mutate(&object)
            return try JSONDecoder().decode(
                GameWorld.self,
                from: JSONSerialization.data(withJSONObject: object)
            )
        }
        func mutateObjects(
            _ mutate: (inout [String: Any]) throws -> Void
        ) throws -> GameWorld {
            try decoded { world in
                var objects = try XCTUnwrap(world["objects"] as? [String: Any])
                try mutate(&objects)
                world["objects"] = objects
            }
        }

        let playerSlot = ObjectHandle(binding.objectHandle).slot
        assertRejected(.freeList, try mutateObjects { objects in
            var free = try XCTUnwrap(objects["freeSlots"] as? [Int])
            free.append(free[0])
            objects["freeSlots"] = free
        })
        assertRejected(.freeList, try mutateObjects { objects in
            var free = try XCTUnwrap(objects["freeSlots"] as? [Int])
            free.removeLast()
            objects["freeSlots"] = free
        })
        assertRejected(
            .objectHandle(slot: playerSlot),
            try mutateObjects { objects in
                var handles = try XCTUnwrap(objects["handles"] as? [UInt32])
                handles[playerSlot] =
                    binding.objectHandle + ObjectHandle.countIncrement
                objects["handles"] = handles
            }
        )
        assertRejected(
            .objectLocation(slot: playerSlot),
            try mutateObjects { objects in
                var slots = try XCTUnwrap(objects["slots"] as? [Any])
                var player = try XCTUnwrap(
                    slots[playerSlot] as? [String: Any]
                )
                player["location"] = ["room": ["_0": 9_999]]
                slots[playerSlot] = player
                objects["slots"] = slots
            }
        )
        assertRejected(
            .outOfDomain("object \(playerSlot)"),
            try mutateObjects { objects in
                var slots = try XCTUnwrap(objects["slots"] as? [Any])
                var player = try XCTUnwrap(
                    slots[playerSlot] as? [String: Any]
                )
                var position = try XCTUnwrap(
                    player["position"] as? [String: Any]
                )
                position["x"] = 1e30
                player["position"] = position
                slots[playerSlot] = player
                objects["slots"] = slots
            }
        )
        assertRejected(.objectTableShape, try mutateObjects { objects in
            var slots = try XCTUnwrap(objects["slots"] as? [Any])
            slots.removeLast()
            objects["slots"] = slots
        })

        var missingPlayer = world
        missingPlayer.objects.delete(ObjectHandle(binding.objectHandle))
        assertRejected(.missingPlayer, missingPlayer)

        var missingRoom = world
        missingRoom.rooms.removeLast()
        assertRejected(.roomState, missingRoom)

        var extraGoal = world
        extraGoal.goals.append(contentsOf: extraGoal.goals.prefix(1))
        if level.goals.isEmpty {
            extraGoal.goals.append(.init(
                status: 0,
                priority: 0,
                list: 0,
                name: "",
                itemName: "",
                description: "",
                completionMessage: "",
                items: []
            ))
        }
        assertRejected(.goals, extraGoal)

        var nonFinite = world
        nonFinite.energy = .infinity
        assertRejected(.nonFiniteValue("energy"), nonFinite)
        var negativeClock = world
        negativeClock.frameDuration = -0.1
        assertRejected(.nonFiniteValue("clock"), negativeClock)
    }

    func testLoadValidationRejectsHostileNestedIndicesAndCapacities()
        throws
    {
        let concussionLevel = try makePlayerConcussionLevel()
        let concussionWorld = GameSession(
            level: concussionLevel,
            presentationReadyTimestamp: 0
        ).world
        XCTAssertNoThrow(try concussionWorld.validate(against: concussionLevel))
        var maskIndex = concussionWorld
        maskIndex.playerConcussionState?.nextFiringMaskIndex = 2
        assertRejected(
            .indexOutOfRange("playerConcussionState.nextFiringMaskIndex"),
            maskIndex,
            level: concussionLevel
        )
        var missiles = concussionWorld
        let player = concussionWorld.testPlayerObject
        guard case let .room(playerRoom) = player.location else {
            return XCTFail("indoor player")
        }
        let missile = PlayerConcussionMissileState(
            creationOrdinal: 0,
            roomSourceIndex: playerRoom,
            position: player.position,
            orientation: player.orientation,
            velocity: .zero,
            lifeRemaining: 1
        )
        missiles.playerConcussionState?.missiles = Array(
            repeating: missile,
            count: playerConcussionMissilePresentationCapacity + 1
        )
        assertRejected(
            .capacity("playerConcussionState.missiles"),
            missiles,
            level: concussionLevel
        )

        var damagedHandle = concussionWorld
        damagedHandle.playerConcussionState?.explosions = [
            .init(
                creationOrdinal: 0,
                roomSourceIndex: playerRoom,
                position: player.position,
                lifeRemaining: 1,
                shockwaveLifeRemaining: 1,
                damagedObjectHandles: [0x7ff]
            ),
        ]
        assertRejected(
            .objectReference(0x7ff),
            damagedHandle,
            level: concussionLevel
        )

        let guidebotLevel = makeTrainingCameraMonitorLevel()
        let guidebotSession = GameSession(
            level: guidebotLevel,
            presentationReadyTimestamp: 0
        )
        _ = guidebotSession.update(
            at: 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        let deployed = guidebotSession.world
        XCTAssertNotNil(deployed.trainingRobotGuidebotState?.guidebot)
        XCTAssertNoThrow(try deployed.validate(against: guidebotLevel))
        var routeIndex = deployed
        routeIndex.trainingRobotGuidebotState?.guidebot?.routePointIndex =
            deployed.trainingRobotGuidebotState!.guidebot!.route.points.count
        assertRejected(
            .indexOutOfRange("guidebot.routePointIndex"),
            routeIndex,
            level: guidebotLevel
        )
        var projectileRoom = deployed
        projectileRoom.trainingRobotGuidebotState?.projectiles = [
            .init(
                roomSourceIndex: 99_999,
                position: player.position,
                velocity: .zero,
                lifeRemaining: 1
            ),
        ]
        assertRejected(
            .roomReference("roomSourceIndex"),
            projectileRoom,
            level: guidebotLevel
        )

        let dodgeLevel = makeTrainingMovingTargetHandoffLevel()
        let dodgeWorld = GameSession(
            level: dodgeLevel,
            presentationReadyTimestamp: 0
        ).world
        XCTAssertNoThrow(try dodgeWorld.validate(against: dodgeLevel))
        var angles = dodgeWorld
        angles.trainingDodgeAttemptState?.turretAngles = [0]
        assertRejected(
            .indexOutOfRange("trainingDodgeAttemptState.turretAngles"),
            angles,
            level: dodgeLevel
        )
    }

    func testLoadValidationRejectsMissingRequiredObjects() throws {
        let level = makeTrainingMovingTargetHandoffLevel()
        let lesson = try XCTUnwrap(level.trainingOpeningLesson)
        let dodge = try XCTUnwrap(level.trainingDodgeAttempt)
        let world = GameSession(level: level, presentationReadyTimestamp: 0)
            .world
        var missingGoal = world
        missingGoal.objects.delete(
            ObjectHandle(lesson.forwardGoalObjectHandle)
        )
        assertRejected(
            .objectReference(lesson.forwardGoalObjectHandle),
            missingGoal,
            level: level
        )
        var missingTurret = world
        missingTurret.objects.delete(
            ObjectHandle(dodge.dodgeTurretObjectHandle)
        )
        assertRejected(
            .objectReference(dodge.dodgeTurretObjectHandle),
            missingTurret,
            level: level
        )
    }

    func testLoadValidationRejectsNonCanonicalSavedOrientations() throws {
        let level = try makePlayerConcussionLevel()
        let world = GameSession(level: level, presentationReadyTimestamp: 0)
            .world
        let zero = Matrix3(right: .zero, up: .zero, forward: .zero)
        let player = world.testPlayerObject
        var playerBasis = world
        playerBasis.objects[player.handle]?.orientation = zero
        assertRejected(
            .orientation("object \(player.handle.slot)"),
            playerBasis,
            level: level
        )
        guard case let .room(playerRoom) = player.location else {
            return XCTFail("indoor player")
        }
        var missileBasis = world
        missileBasis.playerConcussionState?.missiles = [
            .init(
                creationOrdinal: 0,
                roomSourceIndex: playerRoom,
                position: player.position,
                orientation: .init(
                    right: player.orientation.forward,
                    up: player.orientation.forward,
                    forward: player.orientation.forward
                ),
                velocity: .zero,
                lifeRemaining: 1
            ),
        ]
        assertRejected(.orientation("orientation"), missileBasis, level: level)
    }

    func testLoadValidationRejectsHostileCountersDomainsAndOrphanState()
        throws
    {
        let dodgeLevel = makeTrainingMovingTargetHandoffLevel()
        let dodge = try XCTUnwrap(dodgeLevel.trainingDodgeAttempt)
        let dodgeWorld = GameSession(
            level: dodgeLevel,
            presentationReadyTimestamp: 0
        ).world
        let player = dodgeWorld.testPlayerObject
        guard case let .room(playerRoom) = player.location else {
            return XCTFail("indoor player")
        }
        var firingMask = dodgeWorld
        firingMask.trainingDodgeAttemptState?.firingMaskIndex =
            dodge.turret.gunpoints.count
        assertRejected(
            .indexOutOfRange("trainingDodgeAttemptState.firingMaskIndex"),
            firingMask,
            level: dodgeLevel
        )
        var stillProjectile = dodgeWorld
        stillProjectile.trainingDodgeAttemptState?.projectiles = [
            .init(
                roomSourceIndex: playerRoom,
                position: player.position,
                velocity: .zero,
                lifeRemaining: 1
            ),
        ]
        assertRejected(
            .outOfDomain("trainingDodgeAttemptState.projectiles.velocity"),
            stillProjectile,
            level: dodgeLevel
        )
        var turretAngle = dodgeWorld
        turretAngle.trainingDodgeAttemptState?.turretAngles = [1.5, 0]
        assertRejected(
            .outOfDomain("trainingDodgeAttemptState.turretAngles"),
            turretAngle,
            level: dodgeLevel
        )
        var scriptCounter = dodgeWorld
        scriptCounter.trainingOpeningState?.script030Count = Int.max
        assertRejected(
            .outOfDomain("script030Count"),
            scriptCounter,
            level: dodgeLevel
        )

        let cameraLevel = makeTrainingCameraMonitorLevel()
        XCTAssertNil(cameraLevel.trainingDodgeAttempt)
        let cameraSession = GameSession(
            level: cameraLevel,
            presentationReadyTimestamp: 0
        )
        var orphanDodge = cameraSession.world
        orphanDodge.trainingDodgeAttemptState = TrainingDodgeAttemptState()
        assertRejected(
            .unexpectedState("trainingDodgeAttemptState"),
            orphanDodge,
            level: cameraLevel
        )
        var stillLaser = cameraSession.world
        stillLaser.trainingRobotGuidebotState?.projectiles = [
            .init(
                roomSourceIndex: playerRoom,
                position: player.position,
                velocity: .zero,
                lifeRemaining: 1
            ),
        ]
        assertRejected(
            .outOfDomain("trainingRobotGuidebotState.projectiles.velocity"),
            stillLaser,
            level: cameraLevel
        )

        let concussionLevel = try makePlayerConcussionLevel()
        let concussionWorld = GameSession(
            level: concussionLevel,
            presentationReadyTimestamp: 0
        ).world
        var ordinal = concussionWorld
        ordinal.playerConcussionState?.nextCreationOrdinal = UInt64.max
        assertRejected(
            .outOfDomain("nextCreationOrdinal"),
            ordinal,
            level: concussionLevel
        )
        let concussionPlayer = concussionWorld.testPlayerObject
        guard case let .room(concussionRoom) = concussionPlayer.location
        else {
            return XCTFail("indoor player")
        }
        var explosionLife = concussionWorld
        explosionLife.playerConcussionState?.explosions = [
            .init(
                creationOrdinal: 0,
                roomSourceIndex: concussionRoom,
                position: concussionPlayer.position,
                lifeRemaining: -5,
                shockwaveLifeRemaining: 0
            ),
        ]
        assertRejected(
            .outOfDomain("playerConcussionState.explosions.lifeRemaining"),
            explosionLife,
            level: concussionLevel
        )
        var hugeClock = concussionWorld
        hugeClock.frameDuration = 1e30
        assertRejected(.outOfDomain("frameDuration"), hugeClock, level: concussionLevel)

        // Every saved number and vector component stays within the magnitude
        // bound, so no deadline, timer, or vector overflows its consumer.
        var hugeDeadline = cameraSession.world
        hugeDeadline.trainingRobotGuidebotState?.nextPrimaryFireTime = 1e30
        assertRejected(
            .outOfDomain("nextPrimaryFireTime"),
            hugeDeadline,
            level: cameraLevel
        )
        var hugeVelocity = cameraSession.world
        hugeVelocity.trainingRobotGuidebotState?.projectiles = [
            .init(
                roomSourceIndex: playerRoom,
                position: player.position,
                velocity: .init(x: 1e30, y: 0, z: 0),
                lifeRemaining: 1
            ),
        ]
        assertRejected(.outOfDomain("velocity"), hugeVelocity, level: cameraLevel)

        var ordinalFreeFlare = concussionWorld
        ordinalFreeFlare.playerYellowFlareState?.parents = [
            .init(
                roomSourceIndex: concussionRoom,
                position: concussionPlayer.position,
                orientation: concussionPlayer.orientation,
                velocity: concussionPlayer.orientation.forward,
                lifeRemaining: 1,
                lastParticleDropTime: 0,
                presentedLightDistance: 0
            ),
        ]
        assertRejected(
            .outOfDomain("playerYellowFlareState.parents.creationOrdinal"),
            ordinalFreeFlare,
            level: concussionLevel
        )
    }

    private func assertRejected(
        _ expected: GameWorldValidationError,
        _ candidate: GameWorld,
        level: Level,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try GameSession(
                level: level,
                world: candidate,
                resumedAtTimestamp: 0
            ),
            line: line
        ) {
            XCTAssertEqual(
                $0 as? GameSessionRestoreError,
                .invalidWorld(expected),
                line: line
            )
        }
    }

    private func assertSaveContinuation(
        level: Level,
        prepare: (GameSession) -> Void = { _ in },
        firstInput: InputSnapshot? = nil,
        warmupFrames: Int,
        followFrames: Int,
        atSave: (GameSession) -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try level.validate()
        let root = try makeTemporarySaveRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let profileID = UUID()
        let package = makePackageReference()
        let original = GameSession(
            level: level,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 0x2468_ace0
        )
        prepare(original)
        var timestamp = 0.0
        for frame in 1...warmupFrames {
            timestamp += 0.1
            _ = original.update(
                at: timestamp,
                input: frame == 1 ? firstInput ?? scriptedInput(frame)
                    : scriptedInput(frame)
            )
        }
        atSave(original)

        let saveFile = GameSaveFile(rootURL: root)
        try saveFile.save(
            profileID: profileID,
            package: package,
            world: original.world,
            level: level
        )
        let restored = try saveFile.load(
            profileID: profileID,
            package: package,
            baseLevel: level,
            resumedAtTimestamp: timestamp
        )
        XCTAssertEqual(restored.world, original.world, file: file, line: line)

        for frame in (warmupFrames + 1)...(warmupFrames + followFrames) {
            timestamp += 0.1
            let input = scriptedInput(frame)
            let expected = original.update(at: timestamp, input: input)
            let actual = restored.update(at: timestamp, input: input)
            XCTAssertEqual(actual, expected, "frame \(frame)", file: file, line: line)
            XCTAssertEqual(
                restored.world,
                original.world,
                "frame \(frame)",
                file: file,
                line: line
            )
        }
        XCTAssertEqual(
            try canonicalJSONData(restored.world),
            try canonicalJSONData(original.world),
            file: file,
            line: line
        )
    }

    private func scriptedInput(_ frame: Int) -> InputSnapshot {
        InputSnapshot(
            forward: frame % 7 < 4 ? 1 : -0.5,
            sideways: frame % 5 == 0 ? 0.5 : 0,
            yaw: Float(frame % 9) / 9 - 0.4,
            roll: frame % 11 == 0 ? 0.3 : 0,
            firesPrimaryWeapon: frame % 6 == 0,
            firesPlayerFlare: frame % 13 == 0
        )
    }

    private func makeTemporarySaveRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "revival-gamesave-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        return root
    }

    private func makePackageReference() -> CanonicalPackageReference {
        CanonicalPackageReference(
            identitySHA256: String(repeating: "a", count: 64),
            missionKey: "descent3.mission.pilot-training",
            levelKey: "descent3.level.training-mission"
        )
    }
}
