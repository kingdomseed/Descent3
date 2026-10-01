import XCTest

extension CanonicalLevelTests {
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

    func testCanonicalVoiceClipRejectsSameLengthPCMMutation() throws {
        let level = makeTrainingGalleryBarrierLevel()
        try level.validate()
        var clips = level.voiceClips
        let clip = try XCTUnwrap(clips.last)
        clips[clips.count - 1] = CanonicalVoiceClip(
            sourceName: clip.sourceName,
            sourceEntryIndex: clip.sourceEntryIndex,
            sampleRate: clip.sampleRate,
            channelCount: clip.channelCount,
            frameCount: clip.frameCount,
            pcm16LittleEndian: Data([1, 0]),
            pcmSHA256: clip.pcmSHA256,
            sourceArchive: clip.sourceArchive,
            sourceSHA256: clip.sourceSHA256
        )

        assertValidationError(
            .invalidDependency("Canonical voice clip"),
            replacing(level, voiceClips: clips)
        )
    }

    /// An AI page whose objects are made at run time (the Guide-Bot,
    /// AIInitAll's ObjCreate) is checked against its page model's
    /// batteries, as a placed AI object is against its own model
    /// (WBFireBattery, robotfire.cpp:111).
    func testObjectTablesCheckRuntimeAIPageBatteriesAgainstThePageModel() throws {
        let level = withTrainingGuideBot(makeTrainingRobotGuidebotLevel())
        let index = try XCTUnwrap(level.objectInfos?.firstIndex {
            $0.name == CanonicalObjectInfo.guideBotPageName
        })
        let page = try XCTUnwrap(level.objectInfos?[index])
        XCTAssertNotNil(page.ai)
        XCTAssertNotNil(page.presentation)
        XCTAssertFalse(level.objects.contains {
            $0.definition?.sourceName == CanonicalObjectInfo.guideBotPageName
        })
        try level.validateObjectTables()

        // A model battery the page has no battery for: the page's batteries
        // no longer match the model it fires from.
        let hostile = level.settingModelGuns(
            try XCTUnwrap(page.presentation?.primaryModel),
            gunpoints: [.init(parent: 0, position: .zero, normal: .init(x: 0, y: 0, z: 1))],
            batteries: [.init(gunpoints: [0], turrets: [])]
        )
        XCTAssertThrowsError(try hostile.validateObjectTables()) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidObjectTables("object info GuideBot guns")
            )
        }
    }
}
