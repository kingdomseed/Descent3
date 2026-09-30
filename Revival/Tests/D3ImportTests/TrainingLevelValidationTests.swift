import XCTest

extension CanonicalLevelTests {
    func testPresentHeadlightSoundBindingRejectsNonretailClip() throws {
        let level = makeTrainingFinalGoalLevel()
        XCTAssertFalse(level.soundClips.contains {
            $0.logicalName == "Headlight1"
        })
        XCTAssertNoThrow(
            try level.validate(),
            "older schema-11 packages remain valid without Headlight1"
        )
        let existing = try XCTUnwrap(level.soundClips.first)
        let impostor = CanonicalSoundClip(
            logicalName: "Headlight1",
            sourceName: existing.sourceName,
            sourceEntryIndex: existing.sourceEntryIndex,
            sampleRate: existing.sampleRate,
            channelCount: existing.channelCount,
            frameCount: existing.frameCount,
            pcm16LittleEndian: existing.pcm16LittleEndian,
            pcmSHA256: existing.pcmSHA256,
            sourceArchive: existing.sourceArchive,
            sourceSHA256: existing.sourceSHA256,
            importVolume: existing.importVolume
        )
        let hostile = replacing(
            level,
            soundClips: [impostor] + level.soundClips.dropFirst()
        )
        XCTAssertThrowsError(try hostile.validate()) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Headlight1 canonical sound binding")
            )
        }

        let relabeledSource = SourceResource(
            storedIndex: 1_407,
            sourceName: "Headlight.wav"
        )
        let relabeled = CanonicalSoundClip(
            logicalName: "RenamedHeadlight",
            sourceName: relabeledSource.sourceName,
            sourceEntryIndex: relabeledSource.storedIndex,
            sampleRate: existing.sampleRate,
            channelCount: existing.channelCount,
            frameCount: existing.frameCount,
            pcm16LittleEndian: existing.pcm16LittleEndian,
            pcmSHA256: existing.pcmSHA256,
            sourceArchive: existing.sourceArchive,
            sourceSHA256: existing.sourceSHA256,
            importVolume: existing.importVolume
        )
        let relabeledManifest = DependencyManifest(
            current: level.dependencyManifest.current + [
                DependencyRecord(
                    category: "sound",
                    source: relabeledSource,
                    state: "production",
                    provenance: "hostile renamed Headlight fixture"
                ),
            ],
            historicalEagerBaseline:
                level.dependencyManifest.historicalEagerBaseline
        )
        let renamedIdentity = replacing(
            level,
            soundClips: level.soundClips + [relabeled],
            dependencyManifest: relabeledManifest
        )
        XCTAssertThrowsError(try renamedIdentity.validate()) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Headlight1 canonical sound binding")
            )
        }
    }

    func testSchemaElevenRequiresExactFollowBotDestructionHandoff()
        throws
    {
        let level = makeTrainingMovingTargetHandoffLevel()
        let handoff = try XCTUnwrap(level.trainingFollowBotDestruction)

        XCTAssertEqual(handoff.followBotObjectHandle, 8_200)
        XCTAssertEqual(handoff.destroyBot2ObjectHandle, 4_112)
        XCTAssertEqual(handoff.destroyBot1ObjectHandle, 4_113)
        XCTAssertEqual(handoff.combat, .stockTraining)
        XCTAssertEqual(handoff.projectileModel.sourceName, "bluelaser.OOF")
        XCTAssertEqual(handoff.destructionDelay, 2)
        XCTAssertEqual(handoff.levelTimerID, 11)
        XCTAssertEqual(handoff.movingTeamFlags, 65_536)
        XCTAssertEqual(handoff.movingPathIndex, 0)
        XCTAssertEqual(handoff.movingPathGoalFlags, 0x80_11_00)
        XCTAssertEqual(handoff.goalID, -1)
        XCTAssertEqual(handoff.goalPriority, 3)
        XCTAssertEqual(handoff.successMessage, "Excellent!")
        XCTAssertEqual(
            handoff.movingInstruction,
            "Now destroy 2 more robots. This time they will be moving."
        )
        XCTAssertEqual(handoff.voiceSourceName, "kill1.osf")
        XCTAssertFalse(
            try XCTUnwrap(
                level.objectPresentations.first {
                    $0.objectHandle == handoff.destroyBot2ObjectHandle
                }
            ).isVisible
        )
        XCTAssertFalse(
            try XCTUnwrap(
                level.objectPresentations.first {
                    $0.objectHandle == handoff.destroyBot1ObjectHandle
                }
            ).isVisible
        )
        XCTAssertNoThrow(try level.validate())
    }

    func testManeuverFixtureCarriesStockPathsAndFlyerAI() throws {
        let level = makeTrainingManeuverFollowLevel()
        XCTAssertEqual(level.paths[0].name, "FollowLoop1")
        XCTAssertEqual(level.paths[0].nodes.count, 13)
        XCTAssertEqual(level.paths[1].name, "GoToDie")
        XCTAssertEqual(level.paths[1].nodes.count, 1)
        let bot = try XCTUnwrap(level.objects.first { $0.handle == 8_200 })
        XCTAssertEqual(bot.flags, 5_121)
        XCTAssertEqual(bot.location, .room(37))
        let ai = try XCTUnwrap(level.objectInfo(for: ObjectHandle(bot.handle))?.ai)
        XCTAssertEqual(ai.maxVelocity, 40)
        XCTAssertEqual(ai.maxDeltaVelocity, 80)
        XCTAssertEqual(ai.maxTurnRate, 12_000)
        XCTAssertEqual(ai.maxDeltaTurnRate, 16_000)
        XCTAssertEqual(ai.circleDistance, 25)
        XCTAssertNoThrow(try level.validate())
    }

    func testObjectTablesRejectHostileWeaponsBatteriesAndGuns() throws {
        let level = makeTrainingDodgeAttemptLevel()
        XCTAssertNoThrow(try level.validate())
        let encoded = try JSONEncoder().encode(level)

        func hostile(
            _ mutate: (inout [String: Any]) throws -> Void
        ) throws -> Level {
            var object = try XCTUnwrap(
                JSONSerialization.jsonObject(with: encoded)
                    as? [String: Any]
            )
            try mutate(&object)
            return try JSONDecoder().decode(
                Level.self,
                from: JSONSerialization.data(withJSONObject: object)
            )
        }

        assertValidationError(
            .invalidObjectTables("weapon Laser Level 1 - Red"),
            try hostile { object in
                var weapons = try XCTUnwrap(
                    object["weapons"] as? [[String: Any]]
                )
                weapons[0]["sounds"] = ["", "", ""]
                object["weapons"] = weapons
            }
        )
        assertValidationError(
            .invalidObjectTables("weapon names"),
            try hostile { object in
                let weapons = try XCTUnwrap(
                    object["weapons"] as? [[String: Any]]
                )
                object["weapons"] = weapons + weapons
            }
        )
        assertValidationError(
            .invalidObjectTables("object info Hangturret"),
            try hostile { object in
                var infos = try XCTUnwrap(
                    object["objectInfos"] as? [[String: Any]]
                )
                let index = try XCTUnwrap(infos.firstIndex {
                    ($0["name"] as? String) == "Hangturret"
                })
                var batteries = try XCTUnwrap(
                    infos[index]["weaponBatteries"] as? [[String: Any]]
                )
                batteries[0]["gunpointWeapons"] = ["No Such Weapon"]
                infos[index]["weaponBatteries"] = batteries
                object["objectInfos"] = infos
            }
        )
        // Each placed AI object's page matches its model
        // (WBFireBattery, robotfire.cpp:111): one page battery per model
        // battery, a weapon entry per gun point, and a weapon for every
        // gun point a mask fires.
        let turretHandle = level.findObjectName("DodgeTurrett").rawValue
        func hostileTurretBattery(
            _ mutate: @escaping (inout [String: Any]) -> Void
        ) throws -> Level {
            try hostile { object in
                var infos = try XCTUnwrap(
                    object["objectInfos"] as? [[String: Any]]
                )
                let index = try XCTUnwrap(infos.firstIndex {
                    ($0["name"] as? String) == "Hangturret"
                })
                var batteries = try XCTUnwrap(
                    infos[index]["weaponBatteries"] as? [[String: Any]]
                )
                mutate(&batteries[0])
                infos[index]["weaponBatteries"] = batteries
                object["objectInfos"] = infos
            }
        }
        assertValidationError(
            .invalidObjectTables("object \(turretHandle) guns"),
            try hostileTurretBattery {
                $0["gunpointWeapons"] = [
                    "Laser Level 1 - Red", "Laser Level 1 - Red",
                ]
            }
        )
        assertValidationError(
            .invalidObjectTables("object \(turretHandle) guns"),
            try hostileTurretBattery {
                $0["gunpointWeapons"] = ["", "Laser Level 1 - Red", ""]
            }
        )
        assertValidationError(
            .invalidObjectTables("object \(turretHandle) guns"),
            try hostile { object in
                var infos = try XCTUnwrap(
                    object["objectInfos"] as? [[String: Any]]
                )
                let index = try XCTUnwrap(infos.firstIndex {
                    ($0["name"] as? String) == "Hangturret"
                })
                var batteries = try XCTUnwrap(
                    infos[index]["weaponBatteries"] as? [[String: Any]]
                )
                batteries.append(batteries[0])
                infos[index]["weaponBatteries"] = batteries
                object["objectInfos"] = infos
            }
        )
        let turretModel = try XCTUnwrap(
            level.models.first { $0.gunpoints != nil }
        )
        assertValidationError(
            .invalidObjectTables(
                "model guns \(turretModel.source.sourceName)"
            ),
            try hostile { object in
                var models = try XCTUnwrap(
                    object["models"] as? [[String: Any]]
                )
                let index = try XCTUnwrap(models.firstIndex {
                    $0["gunpoints"] != nil
                })
                var gunpoints = try XCTUnwrap(
                    models[index]["gunpoints"] as? [[String: Any]]
                )
                gunpoints[0]["parent"] = 99
                models[index]["gunpoints"] = gunpoints
                object["models"] = models
            }
        )
    }
}
