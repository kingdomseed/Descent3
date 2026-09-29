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
        let lesson = try XCTUnwrap(
            level.trainingDodgeAttempt?.maneuverFollow
        )
        let handoff = try XCTUnwrap(lesson.destructionHandoff)

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

    func testOwnedFollowBotHandoffRejectsHostileRetailProvenance()
        throws
    {
        let fallbackPath =
            "/tmp/revival-followbot-handoff-visibility-corrected-import-3/training.revival/levels/descent3.level.training-mission/level.json"
        let path = ProcessInfo.processInfo.environment[
            "REVIVAL_FOLLOWBOT_HANDOFF_OWNED_LEVEL"
        ] ?? fallbackPath
        let stockLevel = try JSONDecoder().decode(
            Level.self,
            from: Data(contentsOf: URL(fileURLWithPath: path))
        )
        XCTAssertNoThrow(try stockLevel.validate())
        let handoff = try XCTUnwrap(
            stockLevel.trainingDodgeAttempt?.maneuverFollow?
                .destructionHandoff
        )
        XCTAssertEqual(handoff.projectileModel.storedIndex, 16)
        XCTAssertEqual(
            stockLevel.models.first {
                $0.source == handoff.projectileModel
            }?.sourceSHA256,
            "717a9a2ac254eba76c7992fc834e3a5bc3992f86674af972afd9cf0c2967b31b"
        )
        XCTAssertEqual(
            stockLevel.voiceClips.first {
                $0.sourceName == handoff.voiceSourceName
            }?.pcmSHA256,
            "0b1eae26d812929a08faa05efde07926dc4a96ac3873320b6f39805f69877b06"
        )

        var authoredLevel = stockLevel
        let authoredDestroyBot1Index = try XCTUnwrap(
            authoredLevel.objects.firstIndex {
                $0.handle == handoff.destroyBot1ObjectHandle
            }
        )
        let authoredPosition =
            authoredLevel.objects[authoredDestroyBot1Index].position
        authoredLevel.objects[authoredDestroyBot1Index].position =
            .init(
                x: authoredPosition.x + 0.25,
                y: authoredPosition.y,
                z: authoredPosition.z
            )
        XCTAssertNoThrow(try authoredLevel.validateForAuthoring())

        var hostileObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(stockLevel)
            ) as? [String: Any]
        )
        var hostileVoices = try XCTUnwrap(
            hostileObject["voiceClips"] as? [[String: Any]]
        )
        let killIndex = try XCTUnwrap(
            hostileVoices.firstIndex {
                ($0["sourceName"] as? String) == "kill1.osf"
            }
        )
        hostileVoices[killIndex]["sourceSHA256"] = String(repeating: "0", count: 64)
        hostileObject["voiceClips"] = hostileVoices
        let hostileVoiceLevel = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(withJSONObject: hostileObject)
        )
        assertValidationError(
            .invalidDependency(
                "Training Scripts 031,037,027 stock package"
            ),
            hostileVoiceLevel
        )

        hostileObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(stockLevel)
            ) as? [String: Any]
        )
        hostileVoices = try XCTUnwrap(
            hostileObject["voiceClips"] as? [[String: Any]]
        )
        let hostilePCMString = try XCTUnwrap(
            hostileVoices[killIndex]["pcm16LittleEndian"] as? String
        )
        var hostilePCM = try XCTUnwrap(
            Data(base64Encoded: hostilePCMString)
        )
        hostilePCM[hostilePCM.startIndex] ^= 0xff
        hostileVoices[killIndex]["pcm16LittleEndian"] =
            hostilePCM.base64EncodedString()
        hostileVoices[killIndex]["pcmSHA256"] =
            canonicalSHA256(hostilePCM)
        hostileObject["voiceClips"] = hostileVoices
        let hostilePCMLevel = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(withJSONObject: hostileObject)
        )
        assertValidationError(
            .invalidDependency(
                "Training Scripts 031,037,027 stock package"
            ),
            hostilePCMLevel
        )

        hostileObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(stockLevel)
            ) as? [String: Any]
        )
        var hostileObjects = try XCTUnwrap(
            hostileObject["objects"] as? [[String: Any]]
        )
        let destroyBot1Index = try XCTUnwrap(
            hostileObjects.firstIndex {
                ($0["handle"] as? UInt32) == 4_113
                    || ($0["handle"] as? Int) == 4_113
            }
        )
        hostileObjects[destroyBot1Index]["orientation"] = [
            "right": ["x": 1, "y": 0, "z": 0],
            "up": ["x": 0, "y": 1, "z": 0],
            "forward": ["x": 0, "y": 0, "z": 1],
        ]
        hostileObject["objects"] = hostileObjects
        let hostilePoseLevel = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(withJSONObject: hostileObject)
        )
        assertValidationError(
            .invalidDependency(
                "Training Scripts 031,037,027 stock package"
            ),
            hostilePoseLevel
        )
    }

    func testSchemaElevenLeavesTrainingManeuverFollowOptionalForOlderPackages()
        throws
    {
        let current = makeTrainingManeuverFollowLevel()
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(current)
            ) as? [String: Any]
        )
        var hostileObject = object
        var hostileDodge = try XCTUnwrap(
            hostileObject["trainingDodgeAttempt"]
                as? [String: Any]
        )
        var hostileLesson = try XCTUnwrap(
            hostileDodge["maneuverFollow"] as? [String: Any]
        )
        hostileLesson["headingControlMask"] = 769
        hostileDodge["maneuverFollow"] = hostileLesson
        hostileObject["trainingDodgeAttempt"] = hostileDodge
        var dodge = try XCTUnwrap(
            object["trainingDodgeAttempt"] as? [String: Any]
        )
        dodge.removeValue(forKey: "maneuverFollow")
        object["trainingDodgeAttempt"] = dodge
        let level = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertNil(
            level.trainingDodgeAttempt?.maneuverFollow
        )
        XCTAssertNoThrow(try level.validate())

        let hostile = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(
                withJSONObject: hostileObject
            )
        )
        let hostileDodgeAttempt = try XCTUnwrap(
            hostile.trainingDodgeAttempt
        )
        XCTAssertThrowsError(
            try validateStockTrainingManeuverFollowPackage(
                try XCTUnwrap(
                    hostileDodgeAttempt.maneuverFollow
                ),
                dodge: hostileDodgeAttempt,
                level: hostile
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency(
                    "Training Scripts 021-026 stock package"
                )
            )
        }
    }

    func testManeuverFollowLessonRequiresExactStockCarrierPathsAndActions()
        throws
    {
        let level = makeTrainingManeuverFollowLevel()
        let lesson = try XCTUnwrap(
            level.trainingDodgeAttempt?.maneuverFollow
        )

        XCTAssertEqual(lesson.maneuverObjectHandle, 2_063)
        XCTAssertEqual(lesson.orderedPortalIndices, [1, 0])
        XCTAssertEqual(lesson.headingControlMask, 768)
        XCTAssertEqual(lesson.pitchControlMask, 192)
        XCTAssertEqual(lesson.bankControlMask, 3_072)
        XCTAssertEqual(lesson.rotationalControlMask, 4_032)
        XCTAssertEqual(lesson.weaponControlMask, 12_288)
        XCTAssertEqual(lesson.followBotObjectHandle, 8_200)
        XCTAssertEqual(lesson.followPathGoalFlags, 0x90_01_04)
        XCTAssertEqual(lesson.destroyPathGoalFlags, 0x11_00)
        XCTAssertEqual(level.paths[0].name, "FollowLoop1")
        XCTAssertEqual(level.paths[0].nodes.count, 13)
        XCTAssertEqual(level.paths[1].name, "GoToDie")
        XCTAssertEqual(level.paths[1].nodes.count, 1)
        XCTAssertEqual(
            canonicalSHA256(try canonicalJSONData(level.paths)),
            "56997a7e05b017a65778bd48badf453f72bdf5f3f34d60fbd1d6cd8b4fdcdbe5"
        )
        XCTAssertEqual(lesson.followBot.collisionRadius, 4.576_441_8)
        XCTAssertEqual(lesson.followBot.maximumVelocity, 40)
        XCTAssertEqual(lesson.followBot.maximumDeltaVelocity, 80)
        XCTAssertEqual(lesson.followBot.maximumTurnRate, 12_000)
        XCTAssertEqual(
            lesson.followBot.maximumDeltaTurnRate,
            16_000
        )
        XCTAssertEqual(lesson.followBot.circleDistance, 25)
        let bot = try XCTUnwrap(
            level.objects.first {
                $0.handle == lesson.followBotObjectHandle
            }
        )
        XCTAssertEqual(bot.flags, 5_121)
        XCTAssertEqual(bot.location, .room(37))
        XCTAssertEqual(bot.definition?.sourceName, "RAS1 Light Security Flyer")
    }

    func testOwnedManeuverFollowPackageAdmissionPinsStockBoundary()
        throws
    {
        let path = try XCTUnwrap(
            ProcessInfo.processInfo.environment[
                "REVIVAL_MANEUVER_FOLLOW_OWNED_LEVEL"
            ],
            "requires the ignored exact-final owned Script 026 level"
        )
        let level = try JSONDecoder().decode(
            Level.self,
            from: Data(contentsOf: URL(fileURLWithPath: path))
        )
        XCTAssertNoThrow(try level.validate())
        let dodge = try XCTUnwrap(level.trainingDodgeAttempt)
        let lesson = try XCTUnwrap(dodge.maneuverFollow)
        XCTAssertNoThrow(
            try validateStockTrainingManeuverFollowPackage(
                lesson,
                dodge: dodge,
                level: level
            )
        )
        XCTAssertEqual(
            level.voiceClips.filter {
                [
                    "intro3.osf",
                    "pitch.osf",
                    "bank.osf",
                    "follow.osf",
                    "intro4.osf",
                ].contains($0.sourceName)
            }.map(\.sourceEntryIndex),
            [12, 20, 1, 3, 13]
        )
        XCTAssertEqual(lesson.followBot.maximumVelocity, 40)
        XCTAssertEqual(lesson.followBot.maximumDeltaVelocity, 80)
        XCTAssertEqual(lesson.followBot.maximumTurnRate, 12_000)
        XCTAssertEqual(
            lesson.followBot.maximumDeltaTurnRate,
            16_000
        )
        XCTAssertEqual(lesson.followBot.circleDistance, 25)
    }

    func testScript019DodgeExitRequiresExactStockBindingsAndMedia() throws {
        let level = makeTrainingDodgeAttemptLevel()
        let dodge = try XCTUnwrap(level.trainingDodgeAttempt)
        let exit = try XCTUnwrap(dodge.dodgeExit)

        XCTAssertEqual(exit.objectHandle, 12_302)
        XCTAssertEqual(exit.collisionRadius, 10.052_409)
        XCTAssertEqual(exit.markerLightObjectHandle, 4_120)
        XCTAssertEqual(exit.markerLightDistance, 50)
        XCTAssertEqual(exit.portalRoomSourceIndex, 36)
        XCTAssertEqual(exit.orderedPortalIndices, [0, 1])
        XCTAssertEqual(exit.disabledControlMask, 62)
        XCTAssertEqual(
            exit.instruction,
            "Now keep moving forward into the next room."
        )
        XCTAssertEqual(exit.voiceSourceName, "proceed4.osf")
        XCTAssertNotNil(
            level.voiceClips.first {
                $0.sourceName == exit.voiceSourceName
            }
        )
        XCTAssertNoThrow(try level.validate())

        var oldLevel = level
        oldLevel.trainingDodgeAttempt?.dodgeExit = nil
        oldLevel = replacing(
            oldLevel,
            voiceClips: oldLevel.voiceClips.filter {
                $0.sourceName != "proceed4.osf"
            },
            dependencyManifest: .init(
                current: oldLevel.dependencyManifest.current.filter {
                    $0.source.sourceName != "proceed4.osf"
                },
                historicalEagerBaseline:
                    oldLevel.dependencyManifest.historicalEagerBaseline
            )
        )
        var oldObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(oldLevel)
            ) as? [String: Any]
        )
        var oldDodge = try XCTUnwrap(
            oldObject["trainingDodgeAttempt"] as? [String: Any]
        )
        oldDodge.removeValue(forKey: "dodgeExit")
        oldObject["trainingDodgeAttempt"] = oldDodge
        let decodedOldLevel = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(withJSONObject: oldObject)
        )
        XCTAssertNil(decodedOldLevel.trainingDodgeAttempt?.dodgeExit)
        XCTAssertNoThrow(try decodedOldLevel.validate())

        var hostileObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(level)
            ) as? [String: Any]
        )
        var hostileDodge = try XCTUnwrap(
            hostileObject["trainingDodgeAttempt"] as? [String: Any]
        )
        var hostileExit = try XCTUnwrap(
            hostileDodge["dodgeExit"] as? [String: Any]
        )
        hostileExit["disabledControlMask"] = 63
        hostileDodge["dodgeExit"] = hostileExit
        hostileObject["trainingDodgeAttempt"] = hostileDodge
        let hostileLevel = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(withJSONObject: hostileObject)
        )
        XCTAssertThrowsError(try hostileLevel.validate())
    }

    func testTimedDodgeAttemptRequiresExactStockBindingsAndMedia() throws {
        let level = makeTrainingDodgeAttemptLevel()
        let dodge = try XCTUnwrap(level.trainingDodgeAttempt)

        XCTAssertEqual(dodge.startDodgeObjectHandle, 4_106)
        XCTAssertEqual(dodge.doneDodgeingGoalObjectHandle, 12_302)
        XCTAssertEqual(dodge.dodgeTurretObjectHandle, 8_199)
        XCTAssertEqual(dodge.flashLightObjectHandle, 4_120)
        XCTAssertEqual(dodge.triggerDelay, 10)
        XCTAssertEqual(dodge.successDelay, 20)
        XCTAssertEqual(dodge.almostDoneDelay, 14)
        XCTAssertEqual(dodge.portalRoomTwoSourceIndex, 49)
        XCTAssertEqual(dodge.portalRoomThreeSourceIndex, 36)
        XCTAssertEqual(dodge.orderedPortalIndices, [0, 1])
        XCTAssertEqual(dodge.disabledControlMask, 3)
        XCTAssertEqual(dodge.enabledDodgeControlMask, 60)
        XCTAssertEqual(dodge.successControlMask, 3)
        XCTAssertEqual(
            dodge.introduction,
            "Next you are going to practice dodging."
        )
        XCTAssertEqual(
            dodge.instruction,
            "To complete this step, dodge the turrett fire for 20 seconds."
        )
        XCTAssertEqual(
            dodge.hitInstruction,
            "Oops, you were hit! Keep moving!"
        )
        XCTAssertEqual(
            dodge.almostDoneInstruction,
            "You are almost done! Keep up the good work!"
        )
        XCTAssertEqual(dodge.successMessage, "Excellent!")
        XCTAssertEqual(
            dodge.leaveInstruction,
            "Now using your sliding skills, proceed forward to the flashing green light."
        )
        XCTAssertEqual(
            [
                dodge.introductionVoiceSourceName,
                dodge.almostDoneVoiceSourceName,
                dodge.successVoiceSourceName,
            ],
            ["intro2.osf", "almost.osf", "proceed3.osf"]
        )
        XCTAssertEqual(dodge.restoredPlayerShields, 100)
        XCTAssertEqual(dodge.successMarkerLightDistance, 50)
        XCTAssertEqual(
            dodge.markerLightPresentation.primaryColor,
            .init(x: 0.2, y: 1, z: 0.2)
        )
        XCTAssertEqual(
            dodge.turret.gunpoints,
            [
                .init(
                    x: 1.706_505_8,
                    y: -2.224_015_2,
                    z: 2.190_463_5
                ),
                .init(
                    x: 0.457_947_73,
                    y: -2.224_015_2,
                    z: 2.190_463_5
                ),
            ]
        )
        XCTAssertEqual(
            dodge.turret.aimingGunpoint,
            .init(
                x: 1.085_584_6,
                y: -2.224_015_2,
                z: 2.190_463_5
            )
        )
        XCTAssertNoThrow(try level.validate())

        let encoded = try JSONEncoder().encode(level)
        let oldPackage = try JSONDecoder().decode(
            Level.self,
            from: JSONEncoder().encode(
                makeTrainingScript015Level()
            )
        )
        XCTAssertNil(oldPackage.trainingDodgeAttempt)
        XCTAssertNoThrow(try oldPackage.validate())

        var hostileObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded)
                as? [String: Any]
        )
        var hostileDodge = try XCTUnwrap(
            hostileObject["trainingDodgeAttempt"]
                as? [String: Any]
        )
        var hostileTurret = try XCTUnwrap(
            hostileDodge["turret"] as? [String: Any]
        )
        hostileTurret["projectileDamage"] = 0
        hostileDodge["turret"] = hostileTurret
        hostileObject["trainingDodgeAttempt"] = hostileDodge
        let hostilePackage = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(
                withJSONObject: hostileObject
            )
        )
        XCTAssertThrowsError(try hostilePackage.validate())

        var hostileTransformObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded)
                as? [String: Any]
        )
        var hostileObjects = try XCTUnwrap(
            hostileTransformObject["objects"] as? [[String: Any]]
        )
        let startIndex = try XCTUnwrap(
            hostileObjects.firstIndex {
                ($0["handle"] as? NSNumber)?.uint32Value == 4_106
            }
        )
        var hostileStart = hostileObjects[startIndex]
        var hostilePosition = try XCTUnwrap(
            hostileStart["position"] as? [String: Any]
        )
        hostilePosition["x"] = 0
        hostileStart["position"] = hostilePosition
        hostileObjects[startIndex] = hostileStart
        hostileTransformObject["objects"] = hostileObjects
        let hostileTransformPackage = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(
                withJSONObject: hostileTransformObject
            )
        )
        XCTAssertThrowsError(try hostileTransformPackage.validate())
    }

    func testTimedDodgeAttemptRejectsHostilePortalMetadataWithoutTrapping()
        throws
    {
        let encoded = try JSONEncoder().encode(
            makeTrainingDodgeAttemptLevel()
        )

        func hostileLevel(
            mutate: (inout [String: Any]) -> Void
        ) throws -> Level {
            var object = try XCTUnwrap(
                JSONSerialization.jsonObject(with: encoded)
                    as? [String: Any]
            )
            var dodge = try XCTUnwrap(
                object["trainingDodgeAttempt"] as? [String: Any]
            )
            mutate(&dodge)
            object["trainingDodgeAttempt"] = dodge
            return try JSONDecoder().decode(
                Level.self,
                from: JSONSerialization.data(withJSONObject: object)
            )
        }

        let hostileRoom = try hostileLevel {
            $0["portalRoomTwoSourceIndex"] = 35
        }
        XCTAssertThrowsError(try hostileRoom.validate())

        let hostilePortal = try hostileLevel {
            $0["orderedPortalIndices"] = [0, 2]
        }
        XCTAssertThrowsError(try hostilePortal.validate())
    }

    func testOwnedTimedDodgePackageAdmissionRejectsHostileMutation()
        throws
    {
        let path = try XCTUnwrap(
            ProcessInfo.processInfo.environment[
                "REVIVAL_DODGE_OWNED_LEVEL"
            ],
            "requires the ignored promoted timed-dodge owned level"
        )
        let stockLevel = try JSONDecoder().decode(
            Level.self,
            from: Data(contentsOf: URL(fileURLWithPath: path))
        )
        XCTAssertNoThrow(try stockLevel.validate())
        let dodge = try XCTUnwrap(stockLevel.trainingDodgeAttempt)
        XCTAssertEqual(
            stockLevel.models.first {
                $0.source == dodge.turret.model
            }?.sourceSHA256,
            "41c69958947ddc7673ddfe2ffb6f559c6892eafed8b759a02b47c05b22f137e4"
        )
        XCTAssertEqual(
            stockLevel.models.first {
                $0.source == dodge.turret.projectileModel
            }?.sourceSHA256,
            "67e6ff8f84fbcbc60b33a61b222e04be6cfbd4b53ad367ac14f82cca2a76a1ab"
        )
        XCTAssertEqual(
            stockLevel.voiceClips.first {
                $0.sourceName == "intro2.osf"
            }?.pcmSHA256,
            "c43858617c694a1c41dbcc2b9b0c31e0b0f73ff7e33423ef3b80bcf501ef9def"
        )
        XCTAssertEqual(
            stockLevel.voiceClips.first {
                $0.sourceName == "almost.osf"
            }?.pcmSHA256,
            "4d90c15e4c1f9a22fb9b4a3808739d6eecd8590b688b10a84abe7bf641ef8017"
        )
        XCTAssertEqual(
            stockLevel.voiceClips.first {
                $0.sourceName == "proceed3.osf"
            }?.pcmSHA256,
            "abc67c37d716253959d0ec615b364b6ff59b896179fc3f93256be3870ed3dabd"
        )
        let exit = try XCTUnwrap(dodge.dodgeExit)
        XCTAssertEqual(
            stockLevel.voiceClips.first {
                $0.sourceName == exit.voiceSourceName
            }?.sourceEntryIndex,
            24
        )
        XCTAssertEqual(
            stockLevel.voiceClips.first {
                $0.sourceName == exit.voiceSourceName
            }?.sourceSHA256,
            "d7442b4192e34ed6b7b529f3b3d555be64ef3437c000611ff7fa57d6989550e9"
        )
        XCTAssertEqual(
            stockLevel.voiceClips.first {
                $0.sourceName == exit.voiceSourceName
            }?.pcmSHA256,
            "92228006e3a802cc067a1650f735cc1a04865bf68d35ab3bc94343049e3dadc7"
        )

        var hostileObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(stockLevel)
            ) as? [String: Any]
        )
        var hostileDodge = try XCTUnwrap(
            hostileObject["trainingDodgeAttempt"] as? [String: Any]
        )
        var hostileTurret = try XCTUnwrap(
            hostileDodge["turret"] as? [String: Any]
        )
        hostileTurret["projectileSpeed"] = 199
        hostileDodge["turret"] = hostileTurret
        hostileObject["trainingDodgeAttempt"] = hostileDodge
        let hostileLevel = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(withJSONObject: hostileObject)
        )
        assertValidationError(
            .invalidDependency("Training timed dodge stock package"),
            hostileLevel
        )

        hostileObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(stockLevel)
            ) as? [String: Any]
        )
        hostileDodge = try XCTUnwrap(
            hostileObject["trainingDodgeAttempt"] as? [String: Any]
        )
        var hostileExit = try XCTUnwrap(
            hostileDodge["dodgeExit"] as? [String: Any]
        )
        hostileExit["voiceSourceName"] = "proceed3.osf"
        hostileDodge["dodgeExit"] = hostileExit
        hostileObject["trainingDodgeAttempt"] = hostileDodge
        let hostileExitLevel = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(withJSONObject: hostileObject)
        )
        assertValidationError(
            .invalidDependency("Training timed dodge attempt"),
            hostileExitLevel
        )
    }

    func testScript015RequiresIndependentFinishCoursePortalsAndProceedVoice()
        throws
    {
        let level = makeTrainingScript015Level()
        let lesson = try XCTUnwrap(
            level.trainingOpeningLesson?.finishCourse
        )
        XCTAssertEqual(lesson.finishCourseObjectHandle, 6_150)
        XCTAssertEqual(lesson.collisionRadius, 10.052_409)
        XCTAssertEqual(lesson.portalRoomSourceIndex, 49)
        XCTAssertEqual(lesson.orderedPortalIndices, [0, 1])
        XCTAssertEqual(lesson.successMessage, "Excellent!")
        XCTAssertEqual(
            lesson.instruction,
            "Continue Sliding down to start the next step."
        )
        XCTAssertEqual(lesson.voiceSourceName, "proceed2.osf")
        XCTAssertEqual(lesson.enabledControlMask, 32)
        XCTAssertEqual(
            level.objectPresentations.first {
                $0.objectHandle == lesson.finishCourseObjectHandle
            }?.isVisible,
            false
        )
        XCTAssertNoThrow(try level.validate())

        var independent = try XCTUnwrap(level.trainingOpeningLesson)
        independent.continueToCourse = nil
        independent.startCourse = nil
        XCTAssertNoThrow(
            try replacing(
                level,
                trainingOpeningLesson: independent
            ).validate()
        )

        var hostileLesson = try XCTUnwrap(level.trainingOpeningLesson)
        hostileLesson.finishCourse = .init(
            finishCourseObjectHandle: lesson.finishCourseObjectHandle,
            collisionRadius: lesson.collisionRadius,
            portalRoomSourceIndex: lesson.portalRoomSourceIndex,
            orderedPortalIndices: lesson.orderedPortalIndices,
            successMessage: lesson.successMessage,
            instruction: lesson.instruction,
            voiceSourceName: lesson.voiceSourceName,
            enabledControlMask: 33
        )
        assertValidationError(
            .invalidDependency(
                "Training Script 015 finish-course lesson"
            ),
            replacing(
                level,
                trainingOpeningLesson: hostileLesson
            )
        )

        var visiblePresentations = level.objectPresentations
        let presentationIndex = try XCTUnwrap(
            visiblePresentations.firstIndex {
                $0.objectHandle == lesson.finishCourseObjectHandle
            }
        )
        let presentation = visiblePresentations[presentationIndex]
        visiblePresentations[presentationIndex] = .init(
            objectHandle: presentation.objectHandle,
            primaryModel: presentation.primaryModel,
            mediumModel: presentation.mediumModel,
            lowModel: presentation.lowModel,
            dyingModel: presentation.dyingModel,
            mediumDistance: presentation.mediumDistance,
            lowDistance: presentation.lowDistance,
            isVisible: true
        )
        assertValidationError(
            .invalidDependency(
                "Training Script 015 finish-course lesson"
            ),
            replacing(
                level,
                objectPresentations: visiblePresentations
            )
        )

        assertValidationError(
            .invalidDependency(
                "Training Script 015 finish-course lesson"
            ),
            replacing(
                level,
                voiceClips: level.voiceClips.filter {
                    $0.sourceName != lesson.voiceSourceName
                }
            )
        )

        let portalRoomIndex = try XCTUnwrap(
            level.rooms.firstIndex {
                $0.sourceIndex == lesson.portalRoomSourceIndex
            }
        )
        let portal = level.rooms[portalRoomIndex].portals[0]
        let connectedRoomIndex = try XCTUnwrap(
            level.rooms.firstIndex {
                $0.sourceIndex == portal.connectedRoom
            }
        )
        var hostileRooms = level.rooms
        let reciprocal =
            hostileRooms[connectedRoomIndex]
                .portals[portal.connectedPortal]
        hostileRooms[connectedRoomIndex]
            .portals[portal.connectedPortal] = .init(
                flags: reciprocal.flags,
                faceIndex: reciprocal.faceIndex,
                connectedRoom: reciprocal.connectedRoom,
                connectedPortal: 1
            )
        assertValidationError(
            .nonreciprocalPortal(
                room: portal.connectedRoom,
                portal: portal.connectedPortal
            ),
            replacing(level, rooms: hostileRooms)
        )

        var olderObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(level)
            ) as? [String: Any]
        )
        var olderOpening = try XCTUnwrap(
            olderObject["trainingOpeningLesson"] as? [String: Any]
        )
        olderOpening.removeValue(forKey: "finishCourse")
        olderObject["trainingOpeningLesson"] = olderOpening
        let olderLevel = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(withJSONObject: olderObject)
        )
        XCTAssertNil(olderLevel.trainingOpeningLesson?.finishCourse)
        XCTAssertNoThrow(try olderLevel.validate())
    }

    func testOwnedScript015PackageAdmissionRejectsHostileStockMutations()
        throws
    {
        let fallbackPath =
            "/tmp/revival-script015-final-import/training.revival/levels/descent3.level.training-mission/level.json"
        let path = ProcessInfo.processInfo.environment[
            "REVIVAL_SCRIPT015_OWNED_LEVEL"
        ] ?? fallbackPath
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip(
                "requires the ignored exact-final owned Script 015 import"
            )
        }
        let stockLevel = try JSONDecoder().decode(
            Level.self,
            from: Data(contentsOf: URL(fileURLWithPath: path))
        )
        XCTAssertNoThrow(try stockLevel.validate())
        let initialSimulation = PlayerSimulation(
            level: stockLevel,
            presentationReadyTimestamp: 0
        )
        var olderContinuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(
                    initialSimulation.continuation
                )
            ) as? [String: Any]
        )
        XCTAssertEqual(
            olderContinuationObject["schemaVersion"] as? Int,
            7
        )
        var olderOpeningState = try XCTUnwrap(
            olderContinuationObject["trainingOpeningState"]
                as? [String: Any]
        )
        olderOpeningState.removeValue(
            forKey: "finishCourseWasPresented"
        )
        olderContinuationObject["trainingOpeningState"] =
            olderOpeningState
        let olderContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: olderContinuationObject
            )
        )
        let restoredOlderSimulation = try PlayerSimulation(
            level: stockLevel,
            continuation: olderContinuation,
            resumedAtTimestamp: 1
        )
        XCTAssertEqual(
            restoredOlderSimulation.continuation,
            initialSimulation.continuation
        )

        let opening = try XCTUnwrap(stockLevel.trainingOpeningLesson)
        let finishCourse = try XCTUnwrap(opening.finishCourse)
        var hostileLesson = opening
        hostileLesson.finishCourse = .init(
            finishCourseObjectHandle:
                finishCourse.finishCourseObjectHandle,
            collisionRadius: finishCourse.collisionRadius,
            portalRoomSourceIndex:
                finishCourse.portalRoomSourceIndex,
            orderedPortalIndices: finishCourse.orderedPortalIndices,
            successMessage: finishCourse.successMessage,
            instruction: "\(finishCourse.instruction) ",
            voiceSourceName: finishCourse.voiceSourceName,
            enabledControlMask: finishCourse.enabledControlMask
        )
        assertValidationError(
            .invalidDependency("Training Script 015 package"),
            replacing(
                stockLevel,
                trainingOpeningLesson: hostileLesson
            )
        )

        var hostileObjects = stockLevel.objects
        let objectIndex = try XCTUnwrap(
            hostileObjects.firstIndex {
                $0.handle == finishCourse.finishCourseObjectHandle
            }
        )
        let stockObject = hostileObjects[objectIndex]
        hostileObjects[objectIndex] = .init(
            handle: stockObject.handle,
            type: stockObject.type,
            storedID: stockObject.storedID,
            definition: stockObject.definition,
            instanceName: stockObject.instanceName,
            flags: stockObject.flags ^ 1,
            doorShields: stockObject.doorShields,
            location: stockObject.location,
            position: stockObject.position,
            orientation: stockObject.orientation,
            containsType: stockObject.containsType,
            containsID: stockObject.containsID,
            containsCount: stockObject.containsCount,
            lifeLeft: stockObject.lifeLeft,
            soundSource: stockObject.soundSource,
            inertScriptName: stockObject.inertScriptName,
            inertModuleName: stockObject.inertModuleName,
            lightmapSubmodels: stockObject.lightmapSubmodels
        )
        assertValidationError(
            .invalidDependency("Training Script 015 package"),
            replacing(stockLevel, objects: hostileObjects)
        )

        let portalRoomIndex = try XCTUnwrap(
            stockLevel.rooms.firstIndex {
                $0.sourceIndex == finishCourse.portalRoomSourceIndex
            }
        )
        var hostileRooms = stockLevel.rooms
        hostileRooms[portalRoomIndex].portals[0].flags &= ~UInt32(1)
        var hostilePortalLevel = stockLevel
        hostilePortalLevel.rooms = hostileRooms
        assertValidationError(
            .invalidDependency("Training timed dodge attempt"),
            hostilePortalLevel
        )

        let voiceIndex = try XCTUnwrap(
            stockLevel.voiceClips.firstIndex {
                $0.sourceName == finishCourse.voiceSourceName
            }
        )
        let proceed2 = stockLevel.voiceClips[voiceIndex]
        var hostileVoices = stockLevel.voiceClips
        hostileVoices[voiceIndex] = .init(
            sourceName: proceed2.sourceName,
            sourceEntryIndex: proceed2.sourceEntryIndex,
            sampleRate: proceed2.sampleRate,
            channelCount: proceed2.channelCount,
            frameCount: proceed2.frameCount,
            pcm16LittleEndian: proceed2.pcm16LittleEndian,
            pcmSHA256: proceed2.pcmSHA256,
            sourceArchive: proceed2.sourceArchive,
            sourceSHA256: String(repeating: "0", count: 64)
        )
        assertValidationError(
            .invalidDependency("Training Script 015 package"),
            replacing(stockLevel, voiceClips: hostileVoices)
        )
    }
}
