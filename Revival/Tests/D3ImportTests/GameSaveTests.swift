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
                // Script 002 ran on frame 11.
                XCTAssertEqual(
                    session.world.testTrainingMission?.script002Count,
                    1
                )
            }
        )
    }

    /// Timers and level module state (Osiris_ProcessTimers,
    /// OsirisLoadandBind.cpp:2285): a world saved while Script 000's 1 s
    /// level timer is pending fires Script 002 on the same frame as the
    /// uninterrupted world.
    func testSavedWorldAdvancesIdenticallyAcrossPendingLevelTimer() throws {
        try assertSaveContinuation(
            level: makeTrainingScript003Level(),
            warmupFrames: 5,
            followFrames: 10,
            atSave: { session in
                XCTAssertEqual(
                    session.world.osirisTimers.entries.count(where: \.isUsed),
                    1
                )
                XCTAssertEqual(
                    session.world.testTrainingMission?.script002Count,
                    0
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
                session.applyTrainingScript036Outcome()
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
        let rasBot1 = ObjectHandle(2_074)
        let placedCount = ObjectTable(level: level).count
        try assertSaveContinuation(
            level: level,
            prepare: { session in
                session.killRobotsAsPlayer([rasBot1.rawValue])
            },
            warmupFrames: 6,
            followFrames: 30,
            atSave: { session in
                XCTAssertNil(session.world.objects[rasBot1])
                // The frame-6 laser pair is in flight at the save, with the
                // death's debris and splinters.
                let weapons = session.world.objects.filter {
                    $0.type == .weapon
                }
                XCTAssertEqual(weapons.count, 2)
                XCTAssertFalse(session.world.objects.filter {
                    $0.type == .debris || $0.type == .splinter
                }.isEmpty)
                let placed = Set(level.objects.map(\.handle))
                XCTAssertEqual(
                    session.world.objects.filter {
                        placed.contains($0.handle.rawValue)
                    }.count,
                    placedCount - 1
                )
                XCTAssertEqual(session.world.playerKillsLevel, 1)
                XCTAssertEqual(session.world.playerScore, 200)
            }
        )
    }

    /// A robot saved while it is dying (CT_DYING, KillObject with a delay,
    /// damage.cpp:1175) finishes its death on the same frame as the
    /// uninterrupted world, and a shockwave in flight continues too.
    func testSavedWorldAdvancesIdenticallyWithADyingRobot() throws {
        let level = makeTrainingRASBot1DeathLevel()
        let rasBot1 = ObjectHandle(2_074)
        try assertSaveContinuation(
            level: level,
            prepare: { session in
                session.world.killObject(
                    rasBot1,
                    killer: session.world.testPlayerObject.handle,
                    damage: 10,
                    deathFlags: DeathFlags.fireball,
                    delayTime: 1.5,
                    level: session.level
                )
            },
            warmupFrames: 6,
            followFrames: 30,
            atSave: { session in
                guard let dying = session.world.objects[rasBot1] else {
                    return XCTFail("RASBot1 is still dying at the save")
                }
                XCTAssertNotEqual(dying.flags & GameObject.dyingFlag, 0)
                XCTAssertNotNil(dying.dying)
                XCTAssertEqual(session.world.playerScore, 0)
            }
        )
    }

    /// PlayerScoreAdd (Player.cpp:3853) adds to the int score and the
    /// int16_t kill counters (player_external_struct.h:150), which wrap in
    /// the source's integer widths; a saved extreme value cannot trap.
    func testScoreAndKillCountersWrapInTheirSourceWidths() throws {
        var world = GameWorld(level: makeTrainingRobotGuidebotLevel())
        world.playerScore = Int32.max
        world.playerKillsLevel = Int16.max
        world.playerFriendlyKillsLevel = Int16.max
        world.playerScoreAdd(200)
        world.playerScoreAdd(-5)
        XCTAssertEqual(world.playerScore, Int32.min &+ 194)
        XCTAssertEqual(world.playerKillsLevel, Int16.min)
        XCTAssertEqual(world.playerFriendlyKillsLevel, Int16.min)
    }

    /// Saved object physics stays in the domains the integrator converts
    /// and divides by: a spin of 1e30 would trap converting to an angle.
    func testSavedPhysicsAndAttachmentsAreBounded() throws {
        let level = makeTrainingRobotGuidebotLevel()
        let base = GameSession(level: level, presentationReadyTimestamp: 0)
            .world
        var world = base
        world.killObject(
            ObjectHandle(4_112), killer: .none, damage: 10, level: level
        )
        let debris = try XCTUnwrap(world.objects.first { $0.type == .debris })
        XCTAssertNoThrow(try world.validate(against: level))
        for bad in [Float(1e30), .nan, .infinity] {
            var hostile = world
            hostile.objects[debris.handle]?.physics?.rotationalVelocity =
                Vector3(x: bad, y: 0, z: 0)
            XCTAssertThrowsError(try hostile.validate(against: level))
        }
        var heavy = world
        heavy.objects[debris.handle]?.physics?.mass = .infinity
        XCTAssertThrowsError(try heavy.validate(against: level))
        var attached = base
        attached.visEffects = [VisEffect(
            id: VisEffect.lightningBoltID,
            roomSourceIndex: level.rooms[0].sourceIndex,
            position: .zero,
            size: 1,
            lifeLeft: 1,
            lifetime: 1,
            creationTime: 0,
            flags: VisEffect.usesLifeLeftFlag | VisEffect.attachedFlag,
            attachedObject: ObjectHandle(4_112)
        )]
        XCTAssertNoThrow(try attached.validate(against: level))
        attached.visEffects[0].attachedObject = nil
        XCTAssertThrowsError(try attached.validate(against: level))
        attached.visEffects[0].attachedObject = ObjectHandle(0xffff_fff0)
        XCTAssertThrowsError(try attached.validate(against: level))
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
        // The player's dynamic battery mask indexes its ship battery's
        // masks (WBFireBattery).
        let player = concussionWorld.testPlayerObject
        guard case let .room(playerRoom) = player.location else {
            return XCTFail("indoor player")
        }
        var maskIndex = concussionWorld
        maskIndex.objects[player.handle]?.weaponBatteries[10]
            .currentFiringMask = 2
        assertRejected(
            .indexOutOfRange("object \(player.handle.slot) weapon battery 10"),
            maskIndex,
            level: concussionLevel
        )
        // VisEffects hold at most MAX_VIS_EFFECTS.
        var effects = concussionWorld
        let effect = VisEffect(
            id: VisEffect.fadingLineID,
            roomSourceIndex: playerRoom,
            position: player.position,
            size: 1,
            lifeLeft: 1,
            lifetime: 1,
            creationTime: 0,
            flags: VisEffect.usesLifeLeftFlag
        )
        effects.visEffects = Array(
            repeating: effect,
            count: VisEffect.capacity + 1
        )
        assertRejected(.capacity("visEffects"), effects, level: concussionLevel)
        var effectRoom = concussionWorld
        var roomless = effect
        roomless.roomSourceIndex = 99_999
        effectRoom.visEffects = [roomless]
        assertRejected(
            .roomReference("roomSourceIndex"),
            effectRoom,
            level: concussionLevel
        )
        // A weapon's parent is a well-formed handle.
        var parentHandle = concussionWorld
        parentHandle.fireWeaponFromPlayer(
            player.handle,
            weaponType: PlayerWeaponState.primary,
            isDown: true,
            downTime: 0.1,
            level: concussionLevel
        )
        let bolt = try XCTUnwrap(parentHandle.objects.first {
            $0.type == .weapon
        })
        XCTAssertNoThrow(try parentHandle.validate(against: concussionLevel))
        parentHandle.objects[bolt.handle]?.parent = ObjectHandle(0x7ff)
        assertRejected(
            .objectReference(0x7ff),
            parentHandle,
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
        let dodgeLevel = makeTrainingMovingTargetHandoffLevel()
        let dodgeWorld = GameSession(
            level: dodgeLevel,
            presentationReadyTimestamp: 0
        ).world
        XCTAssertNoThrow(try dodgeWorld.validate(against: dodgeLevel))
        // The turret's dynamic_wb keeps MAX_WB_TURRETS angles.
        let turret = dodgeLevel.findObjectName("DodgeTurrett")
        var angles = dodgeWorld
        angles.objects[turret]?.weaponBatteries[0].turretAngles = [0]
        assertRejected(
            .indexOutOfRange("object \(turret.slot) weapon battery 0"),
            angles,
            level: dodgeLevel
        )
        // A goal names a node of a game path.
        let followBot = dodgeLevel.findObjectName("FollowBot1")
        var goal = dodgeWorld
        goal.aiGoalFollowPathSimple(
            followBot, pathID: 0, guid: 0, flags: 0, slot: 3,
            level: dodgeLevel
        )
        XCTAssertNoThrow(try goal.validate(against: dodgeLevel))
        goal.objects[followBot]?.ai?.goals[3].staticPathCurrentNode = 99
        assertRejected(
            .indexOutOfRange("object \(followBot.slot) goal"),
            goal,
            level: dodgeLevel
        )
        // A weapon object names a weapon of the level.
        var weapon = dodgeWorld
        let shot = try XCTUnwrap(weapon.createAndFireWeapon(
            position: try XCTUnwrap(weapon.objects[turret]).position,
            direction: .init(x: 0, y: 0, z: -1),
            parent: turret,
            weaponIndex: 0,
            level: dodgeLevel
        ))
        XCTAssertNoThrow(try weapon.validate(against: dodgeLevel))
        weapon.objects[shot]?.weapon = 5
        assertRejected(
            .indexOutOfRange("object \(shot.slot) weapon"),
            weapon,
            level: dodgeLevel
        )
    }

    func testLoadValidationAcceptsMissingScriptObjects() throws {
        let level = makeTrainingMovingTargetHandoffLevel()
        let world = GameSession(level: level, presentationReadyTimestamp: 0)
            .world
        // Scripts and the AI find objects by handle at each use, so a world
        // without one still loads (ObjGet returns NULL, object.cpp:3231).
        for name in ["ForwardGoal", "DodgeTurrett", "FollowBot1"] {
            var missing = world
            missing.objects.delete(level.findObjectName(name))
            XCTAssertNoThrow(try missing.validate(against: level), name)
        }
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
        // A weapon object keeps an orthonormal basis.
        var weaponBasis = world
        weaponBasis.fireWeaponFromPlayer(
            player.handle,
            weaponType: PlayerWeaponState.primary,
            isDown: true,
            downTime: 0.1,
            level: level
        )
        let bolt = try XCTUnwrap(weaponBasis.objects.first {
            $0.type == .weapon
        })
        weaponBasis.objects[bolt.handle]?.orientation = .init(
            right: player.orientation.forward,
            up: player.orientation.forward,
            forward: player.orientation.forward
        )
        assertRejected(
            .orientation("object \(bolt.handle.slot)"),
            weaponBasis,
            level: level
        )
    }

    func testLoadValidationRejectsHostileCountersDomainsAndOrphanState()
        throws
    {
        let dodgeLevel = makeTrainingMovingTargetHandoffLevel()
        let dodgeWorld = GameSession(
            level: dodgeLevel,
            presentationReadyTimestamp: 0
        ).world
        let player = dodgeWorld.testPlayerObject
        guard case let .room(playerRoom) = player.location else {
            return XCTFail("indoor player")
        }
        let turret = dodgeLevel.findObjectName("DodgeTurrett")
        // The firing mask indexes the page's masks (WBFireBattery).
        var firingMask = dodgeWorld
        firingMask.objects[turret]?.weaponBatteries[0].currentFiringMask = 2
        assertRejected(
            .indexOutOfRange("object \(turret.slot) weapon battery 0"),
            firingMask,
            level: dodgeLevel
        )
        // ai_fire wraps turret angles into 0...1.
        var turretAngle = dodgeWorld
        turretAngle.objects[turret]?.weaponBatteries[0].turretAngles[0] = 1.5
        assertRejected(
            .indexOutOfRange("object \(turret.slot) weapon battery 0"),
            turretAngle,
            level: dodgeLevel
        )
        // An AI object keeps one dynamic battery per model battery
        // (WBClearInfo, ObjInit.cpp:817); ai_fire indexes them.
        var noBatteries = dodgeWorld
        noBatteries.objects[turret]?.weaponBatteries = []
        assertRejected(
            .indexOutOfRange("object \(turret.slot) weaponBatteries"),
            noBatteries,
            level: dodgeLevel
        )
        // ai_mem's counters are int16_t (aistruct.h:724-727); a saved count
        // out of that range does not load.
        var hitCountObject = try XCTUnwrap(testWorldObject(dodgeWorld))
        var table = try XCTUnwrap(hitCountObject["objects"] as? [String: Any])
        var slots = try XCTUnwrap(table["slots"] as? [Any])
        var turretSlot = try XCTUnwrap(slots[turret.slot] as? [String: Any])
        var turretAI = try XCTUnwrap(turretSlot["ai"] as? [String: Any])
        var memory = try XCTUnwrap(turretAI["memory"] as? [[String: Any]])
        memory[0]["numberOfHitEnemy"] = Int.max
        turretAI["memory"] = memory
        turretSlot["ai"] = turretAI
        slots[turret.slot] = turretSlot
        table["slots"] = slots
        hitCountObject["objects"] = table
        XCTAssertThrowsError(try decodeTestWorld(hitCountObject))
        var awareness = dodgeWorld
        awareness.objects[turret]?.ai?.awareness = .infinity
        // The world's finite-value sweep names the field.
        assertRejected(
            .nonFiniteValue("awareness"),
            awareness,
            level: dodgeLevel
        )
        var scriptCounter = dodgeWorld
        var counters = try XCTUnwrap(scriptCounter.testTrainingMission)
        counters.script030Count = Int.max
        scriptCounter.levelModule = .trainingMission(counters)
        assertRejected(
            .outOfDomain("script030Count"),
            scriptCounter,
            level: dodgeLevel
        )

        let concussionLevel = try makePlayerConcussionLevel()
        let concussionWorld = GameSession(
            level: concussionLevel,
            presentationReadyTimestamp: 0
        ).world
        let concussionPlayer = concussionWorld.testPlayerObject
        guard case let .room(concussionRoom) = concussionPlayer.location
        else {
            return XCTFail("indoor player")
        }
        // A live visual effect has life left of at most its lifetime.
        var effectLife = concussionWorld
        effectLife.visEffects = [VisEffect(
            id: VisEffect.customExplosionID,
            roomSourceIndex: concussionRoom,
            position: concussionPlayer.position,
            size: 1,
            lifeLeft: 5,
            lifetime: 0.5,
            creationTime: 0,
            flags: VisEffect.usesLifeLeftFlag
        )]
        assertRejected(
            .outOfDomain("visEffects.lifeLeft"),
            effectLife,
            level: concussionLevel
        )
        // An effect that never ages (no VF_USES_LIFELEFT) or whose life
        // already ran out is not a live effect; VisEffectMoveAll marks an
        // effect dead when its life left drops below 0.
        for (lifeLeft, lifetime, flags) in [
            (Float(-1), Float(1e-20), UInt16(0)),
            (0.1, 0.5, 0),
            (-0.1, 0.5, VisEffect.usesLifeLeftFlag),
            (0.1, 0.5, VisEffect.usesLifeLeftFlag | 0x4000),
        ] {
            var unaged = concussionWorld
            unaged.visEffects = [VisEffect(
                id: VisEffect.customExplosionID,
                roomSourceIndex: concussionRoom,
                position: concussionPlayer.position,
                size: 1,
                lifeLeft: lifeLeft,
                lifetime: lifetime,
                creationTime: 0,
                flags: flags,
                customWeapon: 0
            )]
            assertRejected(
                .outOfDomain("visEffects.lifeLeft"),
                unaged,
                level: concussionLevel
            )
        }
        // A shockwave divides by its impact time (DoConcussiveForce).
        var shockwave = concussionWorld
        let wave = try XCTUnwrap(shockwave.objects.create(
            type: .shockwave,
            renderType: .none,
            location: concussionPlayer.location,
            position: concussionPlayer.position,
            orientation: concussionPlayer.orientation
        ))
        shockwave.objects[wave]?.lifeLeft = 0.1
        shockwave.objects[wave]?.shockwave = .init(
            size: 32, time: 0, playerDamage: 19, genericDamage: 19,
            force: 3_000
        )
        assertRejected(
            .outOfDomain("object \(wave.slot) shockwave"),
            shockwave,
            level: concussionLevel
        )
        var ammo = concussionWorld
        ammo.playerWeaponAmmo[10] = -1
        assertRejected(
            .outOfDomain("playerWeaponAmmo"),
            ammo,
            level: concussionLevel
        )
        var hugeClock = concussionWorld
        hugeClock.frameDuration = 1e30
        assertRejected(.outOfDomain("frameDuration"), hugeClock, level: concussionLevel)

        // Every saved number and vector component stays within the magnitude
        // bound, so no deadline, timer, or vector overflows its consumer.
        var hugeVelocity = concussionWorld
        hugeVelocity.fireWeaponFromPlayer(
            concussionPlayer.handle,
            weaponType: PlayerWeaponState.primary,
            isDown: true,
            downTime: 0.1,
            level: concussionLevel
        )
        let bolt = try XCTUnwrap(hugeVelocity.objects.first {
            $0.type == .weapon
        })
        hugeVelocity.objects[bolt.handle]?.velocity = .init(x: 1e30, y: 0, z: 0)
        assertRejected(
            .outOfDomain("object \(bolt.handle.slot)"),
            hugeVelocity,
            level: concussionLevel
        )

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
