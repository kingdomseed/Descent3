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

    func testScript014RequiresHiddenStartCoursePortalAndIntroVoice()
        throws
    {
        let level = makeTrainingScript003Level()
        let lesson = try XCTUnwrap(
            level.trainingOpeningLesson?.startCourse
        )
        XCTAssertEqual(lesson.startCourseObjectHandle, 6_147)
        XCTAssertGreaterThan(lesson.collisionRadius, 0)
        XCTAssertEqual(lesson.portalRoomSourceIndex, 2)
        XCTAssertEqual(lesson.portalIndex, 1)
        XCTAssertEqual(
            lesson.instruction,
            "Now, manuever through this tunnel using the sliding skills you just learned."
        )
        XCTAssertEqual(lesson.voiceSourceName, "intro1.osf")
        XCTAssertEqual(lesson.enabledControlMask, 63)
        XCTAssertEqual(
            level.objectPresentations.first {
                $0.objectHandle == lesson.startCourseObjectHandle
            }?.isVisible,
            false
        )
        XCTAssertNoThrow(try level.validate())

        var independentHistory = try XCTUnwrap(
            level.trainingOpeningLesson
        )
        independentHistory.continueToCourse = nil
        XCTAssertNoThrow(
            try replacing(
                level,
                trainingOpeningLesson: independentHistory
            ).validate()
        )

        var hostileLesson = try XCTUnwrap(level.trainingOpeningLesson)
        hostileLesson.startCourse = .init(
            startCourseObjectHandle: lesson.startCourseObjectHandle,
            collisionRadius: lesson.collisionRadius,
            portalRoomSourceIndex: lesson.portalRoomSourceIndex,
            portalIndex: lesson.portalIndex,
            instruction: lesson.instruction,
            voiceSourceName: lesson.voiceSourceName,
            enabledControlMask: 62
        )
        assertValidationError(
            .invalidDependency(
                "Training Script 014 start-course lesson"
            ),
            replacing(
                level,
                trainingOpeningLesson: hostileLesson
            )
        )

        var visiblePresentations = level.objectPresentations
        let presentationIndex = try XCTUnwrap(
            visiblePresentations.firstIndex {
                $0.objectHandle == lesson.startCourseObjectHandle
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
                "Training Script 014 start-course lesson"
            ),
            replacing(
                level,
                objectPresentations: visiblePresentations
            )
        )

        let portalRoomIndex = try XCTUnwrap(
            level.rooms.firstIndex {
                $0.sourceIndex == lesson.portalRoomSourceIndex
            }
        )
        let portal =
            level.rooms[portalRoomIndex].portals[lesson.portalIndex]
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
                connectedPortal: 0
            )
        assertValidationError(
            .nonreciprocalPortal(room: 2, portal: 1),
            replacing(level, rooms: hostileRooms)
        )

        assertValidationError(
            .invalidDependency(
                "Training Script 014 start-course lesson"
            ),
            replacing(
                level,
                voiceClips: level.voiceClips.filter {
                    $0.sourceName != lesson.voiceSourceName
                }
            )
        )
    }

    func testOwnedScript014PackageAdmissionRejectsHostileStockMutations()
        throws
    {
        let fallbackPath =
            "/tmp/revival-script014-final-import/training.revival/levels/descent3.level.training-mission/level.json"
        let path = ProcessInfo.processInfo.environment[
            "REVIVAL_SCRIPT014_OWNED_LEVEL"
        ] ?? fallbackPath
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip(
                "requires the ignored exact-final owned Script 014 import"
            )
        }
        let stockLevel = try JSONDecoder().decode(
            Level.self,
            from: Data(contentsOf: URL(fileURLWithPath: path))
        )
        XCTAssertNoThrow(try stockLevel.validate())

        let lesson = try XCTUnwrap(stockLevel.trainingOpeningLesson)
        let startCourse = try XCTUnwrap(lesson.startCourse)
        var hostileLesson = lesson
        hostileLesson.startCourse = .init(
            startCourseObjectHandle:
                startCourse.startCourseObjectHandle,
            collisionRadius: startCourse.collisionRadius,
            portalRoomSourceIndex:
                startCourse.portalRoomSourceIndex,
            portalIndex: startCourse.portalIndex,
            instruction: "\(startCourse.instruction) ",
            voiceSourceName: startCourse.voiceSourceName,
            enabledControlMask: startCourse.enabledControlMask
        )
        assertValidationError(
            .invalidDependency("Training Script 014 package"),
            replacing(
                stockLevel,
                trainingOpeningLesson: hostileLesson
            )
        )

        var hostileObjects = stockLevel.objects
        let objectIndex = try XCTUnwrap(
            hostileObjects.firstIndex {
                $0.handle == startCourse.startCourseObjectHandle
            }
        )
        let stockPosition = hostileObjects[objectIndex].position
        hostileObjects[objectIndex].position = .init(
            x: stockPosition.x + 1,
            y: stockPosition.y,
            z: stockPosition.z
        )
        assertValidationError(
            .invalidDependency("Training Script 014 package"),
            replacing(stockLevel, objects: hostileObjects)
        )

        let portalRoomIndex = try XCTUnwrap(
            stockLevel.rooms.firstIndex {
                $0.sourceIndex == startCourse.portalRoomSourceIndex
            }
        )
        var hostileRooms = stockLevel.rooms
        hostileRooms[portalRoomIndex]
            .portals[startCourse.portalIndex].flags &= ~UInt32(1)
        assertValidationError(
            .invalidDependency("Training Script 013 package"),
            replacing(
                stockLevel,
                rooms: hostileRooms,
                surfacePhysics: stockLevel.surfacePhysics
            )
        )

        let voiceIndex = try XCTUnwrap(
            stockLevel.voiceClips.firstIndex {
                $0.sourceName == startCourse.voiceSourceName
            }
        )
        let intro1 = stockLevel.voiceClips[voiceIndex]
        var hostileVoices = stockLevel.voiceClips
        hostileVoices[voiceIndex] = .init(
            sourceName: intro1.sourceName,
            sourceEntryIndex: intro1.sourceEntryIndex,
            sampleRate: intro1.sampleRate,
            channelCount: intro1.channelCount,
            frameCount: intro1.frameCount,
            pcm16LittleEndian: intro1.pcm16LittleEndian,
            pcmSHA256: intro1.pcmSHA256,
            sourceArchive: intro1.sourceArchive,
            sourceSHA256: String(repeating: "0", count: 64)
        )
        assertValidationError(
            .invalidDependency("Training Script 014 package"),
            replacing(stockLevel, voiceClips: hostileVoices)
        )
    }

    func testScript013RequiresExactStartGoalPortalTopologyAndProceedVoice()
        throws
    {
        let level = makeTrainingScript003Level()
        let lesson = try XCTUnwrap(
            level.trainingOpeningLesson?.continueToCourse
        )
        XCTAssertEqual(lesson.startGoalObjectHandle, 12_300)
        XCTAssertEqual(lesson.portalRoomSourceIndex, 2)
        XCTAssertEqual(lesson.orderedPortalIndices, [0, 1])
        XCTAssertEqual(
            lesson.instruction,
            "Continue Sliding down to start the next step."
        )
        XCTAssertEqual(lesson.voiceSourceName, "proceed1.osf")
        XCTAssertNoThrow(try level.validate())

        var missingPredecessor = try XCTUnwrap(
            level.trainingOpeningLesson
        )
        missingPredecessor.repeatReturnDown = nil
        assertValidationError(
            .invalidDependency(
                "Training Script 013 continue-to-course lesson"
            ),
            replacing(level, trainingOpeningLesson: missingPredecessor)
        )

        var hostileLesson = try XCTUnwrap(level.trainingOpeningLesson)
        hostileLesson.continueToCourse = .init(
            startGoalObjectHandle: lesson.startGoalObjectHandle,
            collisionRadius: lesson.collisionRadius,
            portalRoomSourceIndex: lesson.portalRoomSourceIndex,
            orderedPortalIndices: [1, 0],
            instruction: lesson.instruction,
            voiceSourceName: lesson.voiceSourceName
        )
        assertValidationError(
            .invalidDependency(
                "Training Script 013 continue-to-course lesson"
            ),
            replacing(level, trainingOpeningLesson: hostileLesson)
        )

        let portalRoomIndex = try XCTUnwrap(
            level.rooms.firstIndex {
                $0.sourceIndex == lesson.portalRoomSourceIndex
            }
        )
        let portal = level.rooms[portalRoomIndex].portals[0]
        let reciprocalRoomIndex = try XCTUnwrap(
            level.rooms.firstIndex {
                $0.sourceIndex == portal.connectedRoom
            }
        )
        var hostileRooms = level.rooms
        let reciprocal =
            hostileRooms[reciprocalRoomIndex]
                .portals[portal.connectedPortal]
        hostileRooms[reciprocalRoomIndex]
            .portals[portal.connectedPortal] = .init(
                flags: reciprocal.flags,
                faceIndex: reciprocal.faceIndex,
                connectedRoom: reciprocal.connectedRoom,
                connectedPortal: 1,
                boundaryNodeIndex: reciprocal.boundaryNodeIndex,
                pathPoint: reciprocal.pathPoint,
                combineMaster: reciprocal.combineMaster
            )
        assertValidationError(
            .nonreciprocalPortal(
                room: portal.connectedRoom,
                portal: portal.connectedPortal
            ),
            replacing(level, rooms: hostileRooms)
        )

        var compatibleLesson = try XCTUnwrap(
            level.trainingOpeningLesson
        )
        compatibleLesson.continueToCourse = nil
        XCTAssertNoThrow(
            try replacing(
                level,
                trainingOpeningLesson: compatibleLesson
            ).validate()
        )
    }

    func testOwnedScript013PackageAdmissionRejectsHostileStockMutations()
        throws
    {
        let fallbackPath =
            "/tmp/revival-script013-final-import-green.rZvL1j/training.revival/levels/descent3.level.training-mission/level.json"
        let path = ProcessInfo.processInfo.environment[
            "REVIVAL_SCRIPT013_OWNED_LEVEL"
        ] ?? fallbackPath
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip(
                "requires the ignored exact-final owned Script 013 import"
            )
        }
        let stockLevel = try JSONDecoder().decode(
            Level.self,
            from: Data(contentsOf: URL(fileURLWithPath: path))
        )
        XCTAssertNoThrow(try stockLevel.validate())

        let lesson = try XCTUnwrap(stockLevel.trainingOpeningLesson)
        let continueToCourse = try XCTUnwrap(lesson.continueToCourse)
        var hostileLesson = lesson
        hostileLesson.continueToCourse = .init(
            startGoalObjectHandle: continueToCourse.startGoalObjectHandle,
            collisionRadius: continueToCourse.collisionRadius,
            portalRoomSourceIndex:
                continueToCourse.portalRoomSourceIndex,
            orderedPortalIndices: continueToCourse.orderedPortalIndices,
            instruction: "\(continueToCourse.instruction) ",
            voiceSourceName: continueToCourse.voiceSourceName
        )
        assertValidationError(
            .invalidDependency("Training Script 013 package"),
            replacing(
                stockLevel,
                trainingOpeningLesson: hostileLesson
            )
        )

        let portalRoomIndex = try XCTUnwrap(
            stockLevel.rooms.firstIndex {
                $0.sourceIndex
                    == continueToCourse.portalRoomSourceIndex
            }
        )
        var hostileRooms = stockLevel.rooms
        hostileRooms[portalRoomIndex].portals[0].flags &= ~UInt32(1)
        assertValidationError(
            .invalidDependency("Training Script 013 package"),
            replacing(
                stockLevel,
                rooms: hostileRooms,
                surfacePhysics: stockLevel.surfacePhysics
            )
        )

        let proceedIndex = try XCTUnwrap(
            stockLevel.voiceClips.firstIndex {
                $0.sourceName == continueToCourse.voiceSourceName
            }
        )
        let proceed1 = stockLevel.voiceClips[proceedIndex]
        var hostileVoices = stockLevel.voiceClips
        hostileVoices[proceedIndex] = .init(
            sourceName: proceed1.sourceName,
            sourceEntryIndex: proceed1.sourceEntryIndex,
            sampleRate: proceed1.sampleRate,
            channelCount: proceed1.channelCount,
            frameCount: proceed1.frameCount,
            pcm16LittleEndian: proceed1.pcm16LittleEndian,
            pcmSHA256: proceed1.pcmSHA256,
            sourceArchive: proceed1.sourceArchive,
            sourceSHA256: String(repeating: "0", count: 64)
        )
        assertValidationError(
            .invalidDependency("Training Script 013 package"),
            replacing(stockLevel, voiceClips: hostileVoices)
        )
    }

    func testScript012RequiresExactHiddenUpGoalAndExistingMenuBeep() throws {
        let level = makeTrainingScript003Level()
        let lesson = try XCTUnwrap(
            level.trainingOpeningLesson?.repeatReturnDown
        )
        XCTAssertEqual(lesson.upGoalObjectHandle, 18_441)
        XCTAssertEqual(
            lesson.instruction,
            "Now Slide down until you return to the start position."
        )
        XCTAssertEqual(lesson.soundLogicalName, "MenuBeepEnter")
        XCTAssertNoThrow(try level.validate())

        var hostileLesson = try XCTUnwrap(level.trainingOpeningLesson)
        hostileLesson.repeatReturnDown = .init(
            upGoalObjectHandle: 999_999,
            collisionRadius: lesson.collisionRadius,
            instruction: lesson.instruction,
            soundLogicalName: lesson.soundLogicalName
        )
        assertValidationError(
            .invalidDependency(
                "Training Script 012 repeat-return-down lesson"
            ),
            replacing(level, trainingOpeningLesson: hostileLesson)
        )

        var missingPredecessor = try XCTUnwrap(
            level.trainingOpeningLesson
        )
        missingPredecessor.repeatReturnUp = nil
        assertValidationError(
            .invalidDependency(
                "Training Script 012 repeat-return-down lesson"
            ),
            replacing(level, trainingOpeningLesson: missingPredecessor)
        )

        let stockUpGoal = PlacedObject(
            handle: 18_441,
            type: 7,
            storedID: 67,
            definition: .init(
                storedIndex: 67,
                sourceName: "Invisiblepowerup",
                referenceRuntimeIndex: 68
            ),
            instanceName: "UpGoal",
            flags: 4_352,
            doorShields: nil,
            location: .room(1),
            position: .init(
                x: 2_060.6682,
                y: -25.897_497,
                z: 2_204.6843
            ),
            orientation: .init(
                right: .init(x: -1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: -0),
                forward: .init(x: -0, y: -0, z: -1)
            ),
            containsType: 255,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: nil,
            inertScriptName: nil,
            inertModuleName: nil,
            lightmapSubmodels: []
        )
        let stockPresentation = ObjectPresentationReference(
            objectHandle: 18_441,
            primaryModel: .init(
                storedIndex: 6,
                sourceName: "invisiblepowerup.OOF"
            ),
            mediumModel: nil,
            lowModel: nil,
            dyingModel: nil,
            mediumDistance: nil,
            lowDistance: nil,
            isVisible: false
        )
        let stockMenuBeep = CanonicalSoundClip(
            logicalName: "MenuBeepEnter",
            sourceName: "MenuBeepSelectC.wav",
            sourceEntryIndex: 2_079,
            sampleRate: 22_050,
            channelCount: 1,
            frameCount: 2_321,
            pcm16LittleEndian: Data(),
            pcmSHA256:
                "050b01b05e33233f6486c89d18e897a6f219ed8ecd706d6022ef9fdf01383439",
            sourceArchive: "d3.hog",
            sourceSHA256:
                "7176c7fe69ab31912d349065861a512f34f9649a117f6b3c97bee54b68ea2cea",
            importVolume: 0.7
        )
        let stockLesson = TrainingRepeatReturnDownLesson(
            upGoalObjectHandle: 18_441,
            collisionRadius: 10.052_409,
            instruction:
                "Now Slide down until you return to the start position.",
            soundLogicalName: "MenuBeepEnter"
        )
        XCTAssertNoThrow(
            try validateStockTrainingRepeatReturnDownPackage(
                lesson: stockLesson,
                upGoal: stockUpGoal,
                presentation: stockPresentation,
                menuBeep: stockMenuBeep
            )
        )
        var hostileUpGoal = stockUpGoal
        hostileUpGoal.location = .room(2)
        XCTAssertThrowsError(
            try validateStockTrainingRepeatReturnDownPackage(
                lesson: stockLesson,
                upGoal: hostileUpGoal,
                presentation: stockPresentation,
                menuBeep: stockMenuBeep
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training Script 012 package")
            )
        }

        var compatibleLesson = try XCTUnwrap(
            level.trainingOpeningLesson
        )
        compatibleLesson.repeatReturnDown = nil
        compatibleLesson.continueToCourse = nil
        XCTAssertNoThrow(
            try replacing(
                level,
                trainingOpeningLesson: compatibleLesson
            ).validate()
        )
    }

    func testOwnedScript011PackageAdmissionRejectsHostileStockMutations()
        throws
    {
        let fallbackPath =
            "/tmp/revival-script011-final-import.FPw5aQ/training.revival/levels/descent3.level.training-mission/level.json"
        let path = ProcessInfo.processInfo.environment[
            "REVIVAL_SCRIPT011_OWNED_LEVEL"
        ] ?? fallbackPath
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip(
                "requires the ignored exact-final owned Script 011 import"
            )
        }
        let stockLevel = try JSONDecoder().decode(
            Level.self,
            from: Data(contentsOf: URL(fileURLWithPath: path))
        )
        XCTAssertNoThrow(try stockLevel.validate())

        var hostileLesson = try XCTUnwrap(
            stockLevel.trainingOpeningLesson
        )
        let repeatReturnUp = try XCTUnwrap(
            hostileLesson.repeatReturnUp
        )
        hostileLesson.repeatReturnUp = .init(
            startGoalObjectHandle: repeatReturnUp.startGoalObjectHandle,
            collisionRadius: repeatReturnUp.collisionRadius,
            instruction: "Wrong Script 011 instruction",
            voiceSourceName: repeatReturnUp.voiceSourceName
        )
        assertValidationError(
            .invalidDependency("Training Script 011 package"),
            replacing(
                stockLevel,
                trainingOpeningLesson: hostileLesson
            )
        )

        var hostileVoices = stockLevel.voiceClips
        let udownIndex = try XCTUnwrap(
            hostileVoices.firstIndex {
                $0.sourceName.caseInsensitiveCompare("udown.osf")
                    == .orderedSame
            }
        )
        let udown = hostileVoices[udownIndex]
        hostileVoices[udownIndex] = .init(
            sourceName: udown.sourceName,
            sourceEntryIndex: udown.sourceEntryIndex,
            sampleRate: udown.sampleRate,
            channelCount: udown.channelCount,
            frameCount: udown.frameCount,
            pcm16LittleEndian: udown.pcm16LittleEndian,
            pcmSHA256: udown.pcmSHA256,
            sourceArchive: udown.sourceArchive,
            sourceSHA256: String(repeating: "0", count: 64)
        )
        assertValidationError(
            .invalidDependency("Training Script 011 package"),
            replacing(stockLevel, voiceClips: hostileVoices)
        )
    }

    func testScript011RequiresExactHiddenStartGoalAndUDownVoice() throws {
        let stockLevel = makeTrainingScript003Level()
        let repeatReturnUp = try XCTUnwrap(
            stockLevel.trainingOpeningLesson?.repeatReturnUp
        )
        XCTAssertEqual(repeatReturnUp.startGoalObjectHandle, 12_300)
        XCTAssertEqual(
            repeatReturnUp.instruction,
            "Now Slide up  until you stop."
        )
        XCTAssertEqual(repeatReturnUp.voiceSourceName, "udown.osf")
        XCTAssertNoThrow(try stockLevel.validate())

        let fixtureStartGoal = try XCTUnwrap(
            stockLevel.objects.first { $0.handle == 12_300 }
        )
        let stockStartGoal = PlacedObject(
            handle: 12_300,
            type: 7,
            storedID: 67,
            definition: .init(
                storedIndex: 67,
                sourceName: "Invisiblepowerup",
                referenceRuntimeIndex: 68
            ),
            instanceName: "StartGoal",
            flags: 36_864,
            doorShields: nil,
            location: .room(1),
            position: .init(
                x: 2_062.7678,
                y: -134.19601,
                z: 2_201.679
            ),
            orientation: .init(
                right: .init(x: -1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: -0),
                forward: .init(x: -0, y: -0, z: -1)
            ),
            containsType: 255,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: fixtureStartGoal.soundSource,
            inertScriptName: fixtureStartGoal.inertScriptName,
            inertModuleName: fixtureStartGoal.inertModuleName,
            lightmapSubmodels: fixtureStartGoal.lightmapSubmodels
        )
        let stockPresentation = ObjectPresentationReference(
            objectHandle: 12_300,
            primaryModel: .init(
                storedIndex: 6,
                sourceName: "invisiblepowerup.OOF"
            ),
            mediumModel: nil,
            lowModel: nil,
            dyingModel: nil,
            mediumDistance: nil,
            lowDistance: nil,
            isVisible: false
        )
        let fixtureUDown = try XCTUnwrap(
            stockLevel.voiceClips.first {
                $0.sourceName == "udown.osf"
            }
        )
        let stockUDown = CanonicalVoiceClip(
            sourceName: "udown.osf",
            sourceEntryIndex: 36,
            sampleRate: 22_050,
            channelCount: 1,
            frameCount: 37_257,
            pcm16LittleEndian: fixtureUDown.pcm16LittleEndian,
            pcmSHA256:
                "e54d74f7e18603ad90015cef1e7c15cce693e35a394be4a0a45943c07740af2a",
            sourceArchive: "missions/training.mn3",
            sourceSHA256:
                "f9596f8edb16be0821bb7b846b81432b27aa95f08ac621f1ac1f15eb1279aa43"
        )
        let stockLesson = TrainingRepeatReturnUpLesson(
            startGoalObjectHandle: 12_300,
            collisionRadius: 10.052_409,
            instruction: "Now Slide up  until you stop.",
            voiceSourceName: "udown.osf"
        )
        XCTAssertNoThrow(
            try validateStockTrainingRepeatReturnUpPackage(
                lesson: stockLesson,
                startGoal: stockStartGoal,
                presentation: stockPresentation,
                udown: stockUDown
            )
        )

        var hostileStartGoal = stockStartGoal
        hostileStartGoal.location = .room(2)
        XCTAssertThrowsError(
            try validateStockTrainingRepeatReturnUpPackage(
                lesson: stockLesson,
                startGoal: hostileStartGoal,
                presentation: stockPresentation,
                udown: stockUDown
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training Script 011 package")
            )
        }
        let hostileUDown = CanonicalVoiceClip(
            sourceName: stockUDown.sourceName,
            sourceEntryIndex: stockUDown.sourceEntryIndex,
            sampleRate: stockUDown.sampleRate,
            channelCount: stockUDown.channelCount,
            frameCount: stockUDown.frameCount,
            pcm16LittleEndian: stockUDown.pcm16LittleEndian,
            pcmSHA256: stockUDown.pcmSHA256,
            sourceArchive: stockUDown.sourceArchive,
            sourceSHA256: String(repeating: "0", count: 64)
        )
        XCTAssertThrowsError(
            try validateStockTrainingRepeatReturnUpPackage(
                lesson: stockLesson,
                startGoal: stockStartGoal,
                presentation: stockPresentation,
                udown: hostileUDown
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training Script 011 package")
            )
        }

        var divergentLesson = try XCTUnwrap(
            stockLevel.trainingOpeningLesson
        )
        divergentLesson.repeatReturnUp = .init(
            startGoalObjectHandle: 12_301,
            collisionRadius: repeatReturnUp.collisionRadius,
            instruction: repeatReturnUp.instruction,
            voiceSourceName: repeatReturnUp.voiceSourceName
        )
        assertValidationError(
            .invalidDependency(
                "Training Script 011 repeat-return-up lesson"
            ),
            replacing(
                stockLevel,
                trainingOpeningLesson: divergentLesson
            )
        )
    }

    func testOwnedScript010PackageAdmissionRejectsHostileStockMutations()
        throws
    {
        let fallbackPath =
            "/tmp/revival-script010-final-import.3UeqAk/training.revival/levels/descent3.level.training-mission/level.json"
        let path = ProcessInfo.processInfo.environment[
            "REVIVAL_SCRIPT010_OWNED_LEVEL"
        ] ?? fallbackPath
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip(
                "requires the ignored exact-final owned Script 010 import"
            )
        }
        let stockLevel = try JSONDecoder().decode(
            Level.self,
            from: Data(contentsOf: URL(fileURLWithPath: path))
        )
        XCTAssertNoThrow(try stockLevel.validate())

        var hostileObjects = stockLevel.objects
        let leftGoalIndex = try XCTUnwrap(
            hostileObjects.firstIndex { $0.handle == 12_299 }
        )
        hostileObjects[leftGoalIndex].location = .room(2)
        assertValidationError(
            .invalidDependency("Training Script 010 package"),
            replacing(stockLevel, objects: hostileObjects)
        )

        var hostileLesson = try XCTUnwrap(
            stockLevel.trainingOpeningLesson
        )
        let repeatReturnRight = try XCTUnwrap(
            hostileLesson.repeatReturnRight
        )
        hostileLesson.repeatReturnRight = .init(
            leftGoalObjectHandle: repeatReturnRight.leftGoalObjectHandle,
            collisionRadius: repeatReturnRight.collisionRadius,
            instruction: "Wrong Script 010 instruction",
            soundLogicalName: repeatReturnRight.soundLogicalName
        )
        assertValidationError(
            .invalidDependency("Training Script 010 package"),
            replacing(
                stockLevel,
                trainingOpeningLesson: hostileLesson
            )
        )
    }

    func testScript010RequiresExactHiddenLeftGoalAndMenuBeep() throws {
        let stockLevel = makeTrainingScript003Level()
        let repeatReturnRight = try XCTUnwrap(
            stockLevel.trainingOpeningLesson?.repeatReturnRight
        )
        XCTAssertEqual(repeatReturnRight.leftGoalObjectHandle, 12_299)
        XCTAssertEqual(
            repeatReturnRight.instruction,
            "Now Slide right until you return to the start position."
        )
        XCTAssertEqual(repeatReturnRight.soundLogicalName, "MenuBeepEnter")
        XCTAssertNoThrow(try stockLevel.validate())

        let fixtureLeftGoal = try XCTUnwrap(
            stockLevel.objects.first { $0.handle == 12_299 }
        )
        let stockLeftGoal = PlacedObject(
            handle: 12_299,
            type: 7,
            storedID: 67,
            definition: .init(
                storedIndex: 67,
                sourceName: "Invisiblepowerup",
                referenceRuntimeIndex: 68
            ),
            instanceName: "LeftGoal",
            flags: 4_352,
            doorShields: nil,
            location: .room(1),
            position: .init(
                x: 1_958.2805,
                y: -131.22517,
                z: 2_205.8071
            ),
            orientation: .init(
                right: .init(x: -1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: 0),
                forward: .init(x: 0, y: 0, z: -1)
            ),
            containsType: 255,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: fixtureLeftGoal.soundSource,
            inertScriptName: fixtureLeftGoal.inertScriptName,
            inertModuleName: fixtureLeftGoal.inertModuleName,
            lightmapSubmodels: fixtureLeftGoal.lightmapSubmodels
        )
        let stockPresentation = ObjectPresentationReference(
            objectHandle: 12_299,
            primaryModel: .init(
                storedIndex: 6,
                sourceName: "invisiblepowerup.OOF"
            ),
            mediumModel: nil,
            lowModel: nil,
            dyingModel: nil,
            mediumDistance: nil,
            lowDistance: nil,
            isVisible: false
        )
        let fixtureMenuBeep = try XCTUnwrap(
            stockLevel.soundClips.first {
                $0.logicalName == "MenuBeepEnter"
            }
        )
        let stockMenuBeep = CanonicalSoundClip(
            logicalName: "MenuBeepEnter",
            sourceName: "MenuBeepSelectC.wav",
            sourceEntryIndex: 2_079,
            sampleRate: 22_050,
            channelCount: 1,
            frameCount: 2_321,
            pcm16LittleEndian: fixtureMenuBeep.pcm16LittleEndian,
            pcmSHA256:
                "050b01b05e33233f6486c89d18e897a6f219ed8ecd706d6022ef9fdf01383439",
            sourceArchive: "d3.hog",
            sourceSHA256:
                "7176c7fe69ab31912d349065861a512f34f9649a117f6b3c97bee54b68ea2cea",
            importVolume: 0.7
        )
        let stockRepeatReturnRight = TrainingRepeatReturnRightLesson(
            leftGoalObjectHandle: 12_299,
            collisionRadius: 10.052_409,
            instruction:
                "Now Slide right until you return to the start position.",
            soundLogicalName: "MenuBeepEnter"
        )
        XCTAssertNoThrow(
            try validateStockTrainingRepeatReturnRightPackage(
                lesson: stockRepeatReturnRight,
                leftGoal: stockLeftGoal,
                presentation: stockPresentation,
                menuBeep: stockMenuBeep
            )
        )

        var hostileLeftGoal = stockLeftGoal
        hostileLeftGoal.location = .room(2)
        XCTAssertThrowsError(
            try validateStockTrainingRepeatReturnRightPackage(
                lesson: stockRepeatReturnRight,
                leftGoal: hostileLeftGoal,
                presentation: stockPresentation,
                menuBeep: stockMenuBeep
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training Script 010 package")
            )
        }
        let hostileMenuBeep = CanonicalSoundClip(
            logicalName: stockMenuBeep.logicalName,
            sourceName: stockMenuBeep.sourceName,
            sourceEntryIndex: stockMenuBeep.sourceEntryIndex,
            sampleRate: stockMenuBeep.sampleRate,
            channelCount: stockMenuBeep.channelCount,
            frameCount: stockMenuBeep.frameCount,
            pcm16LittleEndian: stockMenuBeep.pcm16LittleEndian,
            pcmSHA256: stockMenuBeep.pcmSHA256,
            sourceArchive: stockMenuBeep.sourceArchive,
            sourceSHA256: stockMenuBeep.sourceSHA256,
            importVolume: 1
        )
        XCTAssertThrowsError(
            try validateStockTrainingRepeatReturnRightPackage(
                lesson: stockRepeatReturnRight,
                leftGoal: stockLeftGoal,
                presentation: stockPresentation,
                menuBeep: hostileMenuBeep
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training Script 010 package")
            )
        }

        var divergentLesson = try XCTUnwrap(
            stockLevel.trainingOpeningLesson
        )
        divergentLesson.repeatReturnRight = .init(
            leftGoalObjectHandle: 12_301,
            collisionRadius: repeatReturnRight.collisionRadius,
            instruction: repeatReturnRight.instruction,
            soundLogicalName: repeatReturnRight.soundLogicalName
        )
        assertValidationError(
            .invalidDependency(
                "Training Script 010 repeat-return-right lesson"
            ),
            replacing(
                stockLevel,
                trainingOpeningLesson: divergentLesson
            )
        )
    }

    func testScript009RequiresExactHiddenStartGoalAndLRightVoice() throws {
        let stockLevel = makeTrainingScript003Level()
        let repeatReturnLeft = try XCTUnwrap(
            stockLevel.trainingOpeningLesson?.repeatReturnLeft
        )
        XCTAssertEqual(repeatReturnLeft.startGoalObjectHandle, 12_300)
        XCTAssertEqual(
            repeatReturnLeft.instruction,
            "Now Go Left until you stop."
        )
        XCTAssertEqual(repeatReturnLeft.voiceSourceName, "lright.osf")
        XCTAssertNoThrow(try stockLevel.validate())

        let fixtureStartGoal = try XCTUnwrap(
            stockLevel.objects.first {
                $0.handle == repeatReturnLeft.startGoalObjectHandle
            }
        )
        let stockLesson = TrainingRepeatReturnLeftLesson(
            startGoalObjectHandle: 12_300,
            collisionRadius: 10.052_409,
            instruction: "Now Go Left until you stop.",
            voiceSourceName: "lright.osf"
        )
        let stockStartGoal = PlacedObject(
            handle: 12_300,
            type: 7,
            storedID: 67,
            definition: .init(
                storedIndex: 67,
                sourceName: "Invisiblepowerup",
                referenceRuntimeIndex: 68
            ),
            instanceName: "StartGoal",
            flags: 36_864,
            doorShields: nil,
            location: .room(1),
            position: .init(
                x: 2_062.7678,
                y: -134.19601,
                z: 2_201.679
            ),
            orientation: .init(
                right: .init(x: -1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: -0),
                forward: .init(x: -0, y: -0, z: -1)
            ),
            containsType: 255,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: fixtureStartGoal.soundSource,
            inertScriptName: fixtureStartGoal.inertScriptName,
            inertModuleName: fixtureStartGoal.inertModuleName,
            lightmapSubmodels: fixtureStartGoal.lightmapSubmodels
        )
        let stockPresentation = ObjectPresentationReference(
            objectHandle: 12_300,
            primaryModel: .init(
                storedIndex: 6,
                sourceName: "invisiblepowerup.OOF"
            ),
            mediumModel: nil,
            lowModel: nil,
            dyingModel: nil,
            mediumDistance: nil,
            lowDistance: nil,
            isVisible: false
        )
        let fixtureLRight = try XCTUnwrap(
            stockLevel.voiceClips.first {
                $0.sourceName == "lright.osf"
            }
        )
        let stockLRight = CanonicalVoiceClip(
            sourceName: "lright.osf",
            sourceEntryIndex: 19,
            sampleRate: 22_050,
            channelCount: 1,
            frameCount: 43_289,
            pcm16LittleEndian: fixtureLRight.pcm16LittleEndian,
            pcmSHA256:
                "db92df633fdc0010fe9c5cc89f452ea79107e0abdfd4a1ff1e845220abf8b7b5",
            sourceArchive: "missions/training.mn3",
            sourceSHA256:
                "234c82a439232af1072a7cb6aef8e6d14b6432a2c7a642f7a8e4904a01e88294"
        )
        XCTAssertNoThrow(
            try validateStockTrainingRepeatReturnLeftPackage(
                lesson: stockLesson,
                startGoal: stockStartGoal,
                presentation: stockPresentation,
                lright: stockLRight
            )
        )

        var hostileStartGoal = stockStartGoal
        hostileStartGoal.location = .room(2)
        XCTAssertThrowsError(
            try validateStockTrainingRepeatReturnLeftPackage(
                lesson: stockLesson,
                startGoal: hostileStartGoal,
                presentation: stockPresentation,
                lright: stockLRight
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training Script 009 package")
            )
        }
        let wrongLRight = CanonicalVoiceClip(
            sourceName: stockLRight.sourceName,
            sourceEntryIndex: stockLRight.sourceEntryIndex,
            sampleRate: stockLRight.sampleRate,
            channelCount: stockLRight.channelCount,
            frameCount: stockLRight.frameCount,
            pcm16LittleEndian: stockLRight.pcm16LittleEndian,
            pcmSHA256: stockLRight.pcmSHA256,
            sourceArchive: stockLRight.sourceArchive,
            sourceSHA256: String(repeating: "0", count: 64)
        )
        XCTAssertThrowsError(
            try validateStockTrainingRepeatReturnLeftPackage(
                lesson: stockLesson,
                startGoal: stockStartGoal,
                presentation: stockPresentation,
                lright: wrongLRight
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training Script 009 package")
            )
        }

        var authoredObjects = stockLevel.objects
        let authoredTargetIndex = try XCTUnwrap(
            authoredObjects.firstIndex {
                $0.handle == repeatReturnLeft.startGoalObjectHandle
            }
        )
        let authoredPosition = authoredObjects[authoredTargetIndex].position
        authoredObjects[authoredTargetIndex].position = .init(
            x: authoredPosition.x + 1,
            y: authoredPosition.y,
            z: authoredPosition.z
        )
        XCTAssertNoThrow(
            try replacing(
                stockLevel,
                objects: authoredObjects
            ).validateForAuthoring()
        )

        assertValidationError(
            .invalidDependency(
                "Training Script 009 repeat-return-left lesson"
            ),
            replacing(
                stockLevel,
                voiceClips: stockLevel.voiceClips.filter {
                    $0.sourceName != "lright.osf"
                }
            )
        )

        var divergentLesson = try XCTUnwrap(
            stockLevel.trainingOpeningLesson
        )
        let leftGoal = try XCTUnwrap(
            stockLevel.objects.first { $0.handle == 12_299 }
        )
        let leftGoalPresentation = try XCTUnwrap(
            stockLevel.objectPresentations.first {
                $0.objectHandle == leftGoal.handle
            }
        )
        let leftGoalModel = try XCTUnwrap(
            stockLevel.models.first {
                $0.source == leftGoalPresentation.primaryModel
            }
        )
        divergentLesson.repeatReturnLeft = .init(
            startGoalObjectHandle: leftGoal.handle,
            collisionRadius: sourceObjectPresentationSize(
                model: leftGoalModel,
                objectType: leftGoal.type
            ),
            instruction: repeatReturnLeft.instruction,
            voiceSourceName: repeatReturnLeft.voiceSourceName
        )
        assertValidationError(
            .invalidDependency(
                "Training Script 009 repeat-return-left lesson"
            ),
            replacing(
                stockLevel,
                trainingOpeningLesson: divergentLesson
            )
        )
    }

    func testScript008RequiresExactHiddenForwardGoalAndMenuBeep() throws {
        var stockLevel = makeTrainingScript003Level()
        stockLevel = replacing(
            stockLevel,
            missionKey: "descent3.mission.pilot-training",
            levelKey: "descent3.level.training-mission",
            source: replacing(
                stockLevel.source,
                archiveSHA256:
                    "fc1d81921cc4b2618e441b7b9d08c4bcb5cff90731be1bfa6f3a7b054fc0cb54",
                levelSHA256:
                    "915a561cd3bd720d88bffed72fe41b4ff711c287711f060ecd9696e2cd5f7d41"
            )
        )
        let repeatForwardGoal = try XCTUnwrap(
            stockLevel.trainingOpeningLesson?.repeatForwardGoal
        )
        let stockRepeatForwardGoal = TrainingRepeatForwardGoalLesson(
            forwardGoalObjectHandle: 12_301,
            collisionRadius: 10.052_409,
            reverseInstruction:
                "Now use the reverse Key to return to where you started!",
            soundLogicalName: "MenuBeepEnter"
        )
        let fixtureForwardGoal = try XCTUnwrap(
            stockLevel.objects.first {
                $0.handle == repeatForwardGoal.forwardGoalObjectHandle
            }
        )
        let forwardGoal = PlacedObject(
            handle: 12_301,
            type: 7,
            storedID: 67,
            definition: .init(
                storedIndex: 67,
                sourceName: "Invisiblepowerup",
                referenceRuntimeIndex: 68
            ),
            instanceName: "ForwardGoal",
            flags: 36_864,
            doorShields: nil,
            location: .room(1),
            position: .init(
                x: 2_060.4836,
                y: -131.22517,
                z: 2_310.928
            ),
            orientation: .init(
                right: .init(
                    x: -0.997_518_1,
                    y: 0,
                    z: 0.070_410_63
                ),
                up: .init(x: 0, y: 1, z: 0),
                forward: .init(
                    x: -0.070_410_63,
                    y: 0,
                    z: -0.997_518_1
                )
            ),
            containsType: 255,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: fixtureForwardGoal.soundSource,
            inertScriptName: fixtureForwardGoal.inertScriptName,
            inertModuleName: fixtureForwardGoal.inertModuleName,
            lightmapSubmodels: fixtureForwardGoal.lightmapSubmodels
        )
        let presentation = ObjectPresentationReference(
            objectHandle: 12_301,
            primaryModel: .init(
                storedIndex: 6,
                sourceName: "invisiblepowerup.OOF"
            ),
            mediumModel: nil,
            lowModel: nil,
            dyingModel: nil,
            mediumDistance: nil,
            lowDistance: nil,
            isVisible: false
        )
        let fixtureMenuBeep = try XCTUnwrap(
            stockLevel.soundClips.first {
                $0.logicalName == repeatForwardGoal.soundLogicalName
            }
        )
        let stockMenuBeep = CanonicalSoundClip(
            logicalName: fixtureMenuBeep.logicalName,
            sourceName: "MenuBeepSelectC.wav",
            sourceEntryIndex: 2_079,
            sampleRate: 22_050,
            channelCount: 1,
            frameCount: 2_321,
            pcm16LittleEndian: fixtureMenuBeep.pcm16LittleEndian,
            pcmSHA256:
                "050b01b05e33233f6486c89d18e897a6f219ed8ecd706d6022ef9fdf01383439",
            sourceArchive: "d3.hog",
            sourceSHA256:
                "7176c7fe69ab31912d349065861a512f34f9649a117f6b3c97bee54b68ea2cea",
            importVolume: 0.7
        )
        XCTAssertNoThrow(
            try validateStockTrainingRepeatForwardGoalPackage(
                lesson: stockRepeatForwardGoal,
                forwardGoal: forwardGoal,
                presentation: presentation,
                menuBeep: stockMenuBeep
            )
        )

        var hostileForwardGoal = forwardGoal
        hostileForwardGoal.orientation = .init(
            right: .init(x: 1, y: 0, z: 0),
            up: .init(x: 0, y: 1, z: 0),
            forward: .init(x: 0, y: 0, z: 1)
        )
        XCTAssertThrowsError(
            try validateStockTrainingRepeatForwardGoalPackage(
                lesson: stockRepeatForwardGoal,
                forwardGoal: hostileForwardGoal,
                presentation: presentation,
                menuBeep: stockMenuBeep
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training Script 008 package")
            )
        }

        let wrongVolumeMenuBeep = CanonicalSoundClip(
            logicalName: stockMenuBeep.logicalName,
            sourceName: stockMenuBeep.sourceName,
            sourceEntryIndex: stockMenuBeep.sourceEntryIndex,
            sampleRate: stockMenuBeep.sampleRate,
            channelCount: stockMenuBeep.channelCount,
            frameCount: stockMenuBeep.frameCount,
            pcm16LittleEndian: stockMenuBeep.pcm16LittleEndian,
            pcmSHA256: stockMenuBeep.pcmSHA256,
            sourceArchive: stockMenuBeep.sourceArchive,
            sourceSHA256: stockMenuBeep.sourceSHA256,
            importVolume: 1
        )
        XCTAssertThrowsError(
            try validateStockTrainingRepeatForwardGoalPackage(
                lesson: stockRepeatForwardGoal,
                forwardGoal: forwardGoal,
                presentation: presentation,
                menuBeep: wrongVolumeMenuBeep
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training Script 008 package")
            )
        }

        var hostileObjects = stockLevel.objects
        let targetIndex = try XCTUnwrap(
            hostileObjects.firstIndex {
                $0.handle == repeatForwardGoal.forwardGoalObjectHandle
            }
        )
        hostileObjects[targetIndex].orientation =
            hostileForwardGoal.orientation
        XCTAssertNoThrow(
            try replacing(
                stockLevel,
                objects: hostileObjects
            ).validateForAuthoring()
        )
    }

    func testScript007RequiresHiddenCollisionActiveStartGoal() throws {
        let level = makeTrainingScript003Level()
        XCTAssertNoThrow(try level.validate())
        var lesson = try XCTUnwrap(level.trainingOpeningLesson)
        let repeatForward = try XCTUnwrap(lesson.repeatForward)
        lesson.repeatForwardGoal = nil
        lesson.repeatReturnLeft = nil
        lesson.repeatReturnRight = nil
        lesson.repeatReturnUp = nil
        lesson.repeatReturnDown = nil
        lesson.continueToCourse = nil
        lesson.startCourse = nil
        lesson.returnLeft = nil
        lesson.returnRight = nil
        lesson.returnUp = nil
        let isolatedLevel = replacing(level, trainingOpeningLesson: lesson)
        let presentationIndex = try XCTUnwrap(
            isolatedLevel.objectPresentations.firstIndex {
                $0.objectHandle == repeatForward.startGoalObjectHandle
            }
        )
        var visiblePresentations = isolatedLevel.objectPresentations
        let hidden = visiblePresentations[presentationIndex]
        visiblePresentations[presentationIndex] = .init(
            objectHandle: hidden.objectHandle,
            primaryModel: hidden.primaryModel,
            mediumModel: hidden.mediumModel,
            lowModel: hidden.lowModel,
            dyingModel: hidden.dyingModel,
            mediumDistance: hidden.mediumDistance,
            lowDistance: hidden.lowDistance,
            isVisible: true
        )
        assertValidationError(
            .invalidDependency("Training Script 007 repeat-forward lesson"),
            replacing(isolatedLevel, objectPresentations: visiblePresentations)
        )

        lesson.repeatForward = .init(
            startGoalObjectHandle: 999_999,
            collisionRadius: repeatForward.collisionRadius,
            successMessage: repeatForward.successMessage,
            repeatMessage: repeatForward.repeatMessage,
            forwardInstruction: repeatForward.forwardInstruction,
            voiceSourceName: repeatForward.voiceSourceName
        )
        assertValidationError(
            .invalidDependency("Training Script 007 repeat-forward lesson"),
            replacing(isolatedLevel, trainingOpeningLesson: lesson)
        )

        lesson.repeatForward = repeatForward
        var stockLevel = replacing(
            isolatedLevel,
            trainingOpeningLesson: lesson,
            voiceClips: isolatedLevel.voiceClips.filter {
                !["left1.osf", "return2.osf", "up1.osf"].contains(
                    $0.sourceName
                )
            }
        )
        stockLevel = replacing(
            stockLevel,
            missionKey: "descent3.mission.pilot-training",
            levelKey: "descent3.level.training-mission",
            source: replacing(
                stockLevel.source,
                archiveSHA256:
                    "fc1d81921cc4b2618e441b7b9d08c4bcb5cff90731be1bfa6f3a7b054fc0cb54",
                levelSHA256:
                    "915a561cd3bd720d88bffed72fe41b4ff711c287711f060ecd9696e2cd5f7d41"
            )
        )
        var hostileObjects = stockLevel.objects
        let targetIndex = try XCTUnwrap(
            hostileObjects.firstIndex {
                $0.handle == repeatForward.startGoalObjectHandle
            }
        )
        hostileObjects[targetIndex].orientation = .init(
            right: .init(x: 1, y: 0, z: 0),
            up: .init(x: 0, y: 1, z: 0),
            forward: .init(x: 0, y: 0, z: 1)
        )
        assertValidationError(
            .invalidDependency("Training Script 007 package"),
            replacing(stockLevel, objects: hostileObjects)
        )
        XCTAssertNoThrow(
            try replacing(
                stockLevel,
                objects: hostileObjects
            ).validateForAuthoring()
        )
    }

    func testScript006RequiresHiddenCollisionActiveUpGoal() throws {
        let level = makeTrainingScript003Level()
        XCTAssertNoThrow(try level.validate())
        let lesson = try XCTUnwrap(level.trainingOpeningLesson)
        let returnDown = try XCTUnwrap(lesson.returnDown)
        let presentationIndex = try XCTUnwrap(
            level.objectPresentations.firstIndex {
                $0.objectHandle == returnDown.upGoalObjectHandle
            }
        )
        var visiblePresentations = level.objectPresentations
        let hidden = visiblePresentations[presentationIndex]
        visiblePresentations[presentationIndex] = .init(
            objectHandle: hidden.objectHandle,
            primaryModel: hidden.primaryModel,
            mediumModel: hidden.mediumModel,
            lowModel: hidden.lowModel,
            dyingModel: hidden.dyingModel,
            mediumDistance: hidden.mediumDistance,
            lowDistance: hidden.lowDistance,
            isVisible: true
        )
        assertValidationError(
            .invalidDependency("Training Script 006 return-down lesson"),
            replacing(level, objectPresentations: visiblePresentations)
        )

        var missingTarget = lesson
        missingTarget.returnDown = .init(
            upGoalObjectHandle: 999_999,
            collisionRadius: returnDown.collisionRadius,
            successMessage: returnDown.successMessage,
            instruction: returnDown.instruction,
            voiceSourceName: returnDown.voiceSourceName
        )
        assertValidationError(
            .invalidDependency("Training Script 006 return-down lesson"),
            replacing(level, trainingOpeningLesson: missingTarget)
        )
    }

    func testSchemaElevenValidatesExactTrainingFinalRoomEntryChain()
        throws
    {
        let level = makeTrainingFinalRoomEntryLevel()
        try level.validate()

        XCTAssertEqual(level.schemaVersion, 11)
        let chain = try XCTUnwrap(level.trainingFinalRoomEntryChain)
        XCTAssertEqual(chain.triggerName, "Portal4")
        XCTAssertEqual(chain.triggerRoomSourceIndex, 44)
        XCTAssertEqual(chain.triggerFaceIndex, 1)
        XCTAssertEqual(chain.successMessage, "Excellent!")
        XCTAssertEqual(
            chain.instructionMessage,
            "Now for your final and most difficult task. Locate and destroy the last 5 robots."
        )
        XCTAssertEqual(chain.voiceSourceName, "intro7.osf")

        let stockVoice = CanonicalVoiceClip(
            sourceName: "intro7.osf",
            sourceEntryIndex: 16,
            sampleRate: 22_050,
            channelCount: 1,
            frameCount: 469_201,
            pcm16LittleEndian: Data(),
            pcmSHA256:
                "381ce960f6a266b1014cdcfdfc2cc3607a053d3c4b062215e5512127e7bd2711",
            sourceArchive: "missions/training.mn3",
            sourceSHA256:
                "7348ded9ee2c6735ea712b52647f0bfa7478a508c03c10af5f837741a836c67f"
        )
        XCTAssertNoThrow(
            try validateStockTrainingFinalRoomEntryPackage(
                chain: chain,
                intro7: stockVoice
            )
        )
        let hostilePCM = Data(repeating: 1, count: 469_201 * 2)
        var hostileVoice = stockVoice
        hostileVoice = .init(
            sourceName: hostileVoice.sourceName,
            sourceEntryIndex: hostileVoice.sourceEntryIndex,
            sampleRate: hostileVoice.sampleRate,
            channelCount: hostileVoice.channelCount,
            frameCount: hostileVoice.frameCount,
            pcm16LittleEndian: hostilePCM,
            pcmSHA256: canonicalSHA256(hostilePCM),
            sourceArchive: hostileVoice.sourceArchive,
            sourceSHA256: hostileVoice.sourceSHA256
        )
        XCTAssertThrowsError(
            try validateStockTrainingFinalRoomEntryPackage(
                chain: chain,
                intro7: hostileVoice
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training Script 050 package")
            )
        }

        let trigger = try XCTUnwrap(level.triggers.first {
            $0.name == chain.triggerName
        })
        let hostileTrigger = LevelTrigger(
            name: trigger.name,
            roomIndex: trigger.roomIndex,
            faceIndex: trigger.faceIndex,
            flags: 0,
            activator: trigger.activator
        )
        assertValidationError(
            .invalidDependency("Training Script 050 final-room entry"),
            replacing(
                level,
                triggers: level.triggers.map {
                    $0.name == hostileTrigger.name ? hostileTrigger : $0
                }
            )
        )
    }

    func testSchemaElevenRejectsReroutedReciprocalTrainingFinalRoomBarrier()
        throws
    {
        let level = makeTrainingFinalRoomEntryLevel()
        let reroutedRooms = level.rooms.map { room in
            replacingTrainingRoom(
                room,
                sourceIndex: room.sourceIndex,
                portals: room.portals.enumerated().map {
                    portalIndex, portal in
                    LevelPortal(
                        flags: portal.flags,
                        faceIndex: portal.faceIndex,
                        connectedRoom: {
                            if room.name == "P6 neighbor 0" {
                                if portalIndex == 2 { return 44 }
                                if portalIndex == 3 { return 62 }
                            }
                            return portal.connectedRoom
                        }(),
                        connectedPortal: {
                            if room.name == "PortalRoom6"
                                && portal.connectedRoom == 41 {
                                return 2
                            }
                            if room.name == "P6 auxiliary 2" {
                                return 3
                            }
                            return portal.connectedPortal
                        }(),
                        boundaryNodeIndex: portal.boundaryNodeIndex,
                        pathPoint: portal.pathPoint,
                        combineMaster: portal.combineMaster
                    )
                }
            )
        }
        assertValidationError(
            .invalidDependency("Training Script 050 final-room entry"),
            replacing(
                level,
                rooms: reroutedRooms,
                surfacePhysics: level.surfacePhysics
            )
        )
    }

    func testSchemaElevenValidatesExactTrainingCloakAndLastRoomChain()
        throws
    {
        let level = makeTrainingCloakPickupLevel()
        try level.validate()

        XCTAssertEqual(level.schemaVersion, 11)
        let cloak = try XCTUnwrap(level.trainingCloakPickupChain)
        XCTAssertEqual(cloak.pickupObjectHandle, 2_073)
        XCTAssertEqual(cloak.pickupRoomSourceIndex, 11)
        XCTAssertEqual(cloak.pickupObjectFlags, 5_120)
        XCTAssertEqual(cloak.fadeDuration, 1)
        XCTAssertEqual(cloak.cloakDuration, 30)
        XCTAssertEqual(cloak.activatedMessage, "Cloak On")
        XCTAssertEqual(cloak.expiredMessage, "Cloak Off")
        XCTAssertEqual(cloak.pickupSoundSourceName, "Power03.wav")
        XCTAssertEqual(
            cloak.activatedSoundSourceName,
            "ShpCloakOn.wav"
        )
        XCTAssertEqual(
            cloak.expiredSoundSourceName,
            "ShpCloakOffBeep.wav"
        )
        let lastRoom = try XCTUnwrap(level.trainingLastRoomChain)
        XCTAssertEqual(lastRoom.orderedPortalIndices, [1, 0])
        XCTAssertEqual(lastRoom.markerLightObjectHandle, 4_117)
        XCTAssertEqual(lastRoom.openMarkerLightDistance, 50)
        XCTAssertEqual(lastRoom.timerDuration, 2)
        XCTAssertEqual(
            lastRoom.completionVoiceSourceName,
            "proceed5.osf"
        )

        let missingPickup = replacing(
            level,
            objects: level.objects.filter { $0.handle != 2_073 },
            models: level.models.filter {
                !["cloak.OOF", "CloakMed.OOF", "CloakLow.OOF"]
                    .contains($0.source.sourceName)
            },
            objectPresentations: level.objectPresentations.filter {
                $0.objectHandle != 2_073
            },
            dependencyManifest: .init(
                current: level.dependencyManifest.current.filter {
                    !(
                        $0.category == "model"
                            && [
                                "cloak.OOF",
                                "CloakMed.OOF",
                                "CloakLow.OOF",
                            ].contains($0.source.sourceName)
                    )
                },
                historicalEagerBaseline:
                    level.dependencyManifest.historicalEagerBaseline
            )
        )
        assertValidationError(
            .invalidDependency("Training CloakPowerup2 pickup chain"),
            missingPickup
        )

        let hostileFade = replacing(
            level,
            trainingCloakPickupChain: .init(
                pickupObjectHandle: cloak.pickupObjectHandle,
                pickupRoomSourceIndex: cloak.pickupRoomSourceIndex,
                pickupObjectFlags: cloak.pickupObjectFlags,
                pickupCollisionRadius: cloak.pickupCollisionRadius,
                fadeDuration: 0.5,
                cloakDuration: cloak.cloakDuration,
                activatedMessage: cloak.activatedMessage,
                expiredMessage: cloak.expiredMessage,
                pickupSoundSourceName: cloak.pickupSoundSourceName,
                activatedSoundSourceName:
                    cloak.activatedSoundSourceName,
                expiredSoundSourceName: cloak.expiredSoundSourceName
            )
        )
        assertValidationError(
            .invalidDependency("Training CloakPowerup2 pickup chain"),
            hostileFade
        )

        let cloakModelIndex = try XCTUnwrap(level.models.firstIndex {
            $0.source.sourceName == "cloak.OOF"
        })
        var hostileModels = level.models
        let cloakModel = hostileModels[cloakModelIndex]
        hostileModels[cloakModelIndex] = .init(
            source: cloakModel.source,
            collisionRadius: cloakModel.collisionRadius,
            submodels: cloakModel.submodels,
            bounds: cloakModel.bounds,
            sourceArchive: cloakModel.sourceArchive,
            sourceSHA256: String(repeating: "0", count: 64)
        )
        assertValidationError(
            .invalidDependency("Training CloakPowerup2 pickup chain"),
            replacing(level, models: hostileModels)
        )

        let exactPCMHashes = [
            "Power03.wav":
                "48908714345e648ce9e713d24b9aa66bfe763a82d961a83ca9543852bca8aadc",
            "ShpCloakOn.wav":
                "61b52e468bfbe6bf5bd96ac158ef3ab7fd0d048fa375896c80de83df2129cdb2",
            "ShpCloakOffBeep.wav":
                "8ca941f9d4a30f4b3431af4b86ff153b955885a23c686fa56fb7a8d0bfa0e87d",
        ]
        let stockSounds = level.soundClips.map { clip in
            guard let exactPCMHash = exactPCMHashes[clip.sourceName]
            else { return clip }
            return CanonicalSoundClip(
                logicalName: clip.logicalName,
                sourceName: clip.sourceName,
                sourceEntryIndex: clip.sourceEntryIndex,
                sampleRate: clip.sampleRate,
                channelCount: clip.channelCount,
                frameCount: clip.frameCount,
                pcm16LittleEndian: clip.pcm16LittleEndian,
                pcmSHA256: exactPCMHash,
                sourceArchive: clip.sourceArchive,
                sourceSHA256: clip.sourceSHA256,
                importVolume: clip.importVolume
            )
        }
        XCTAssertNoThrow(
            try validateStockTrainingCloakSoundPackage(stockSounds)
        )
        for sourceName in exactPCMHashes.keys.sorted() {
            var hostileSounds = stockSounds
            let index = try XCTUnwrap(hostileSounds.firstIndex {
                $0.sourceName == sourceName
            })
            let clip = hostileSounds[index]
            let hostilePCM = Data(
                repeating: 1,
                count: clip.pcm16LittleEndian.count
            )
            hostileSounds[index] = .init(
                logicalName: clip.logicalName,
                sourceName: clip.sourceName,
                sourceEntryIndex: clip.sourceEntryIndex,
                sampleRate: clip.sampleRate,
                channelCount: clip.channelCount,
                frameCount: clip.frameCount,
                pcm16LittleEndian: hostilePCM,
                pcmSHA256: canonicalSHA256(hostilePCM),
                sourceArchive: clip.sourceArchive,
                sourceSHA256: clip.sourceSHA256,
                importVolume: clip.importVolume
            )
            XCTAssertThrowsError(
                try validateStockTrainingCloakSoundPackage(hostileSounds),
                sourceName
            ) {
                XCTAssertEqual(
                    $0 as? LevelValidationError,
                    .invalidDependency("Training CloakPowerup2 package")
                )
            }
        }

        let hostileMarkerPresentation = replacing(
            level,
            trainingLastRoomChain: .init(
                barrierRoomSourceIndex:
                    lastRoom.barrierRoomSourceIndex,
                orderedPortalIndices:
                    lastRoom.orderedPortalIndices,
                markerLightObjectHandle:
                    lastRoom.markerLightObjectHandle,
                markerLightPresentation: .init(
                    primaryColor: .zero,
                    secondaryColor:
                        lastRoom.markerLightPresentation.secondaryColor,
                    timeInterval:
                        lastRoom.markerLightPresentation.timeInterval,
                    flickerDistance:
                        lastRoom.markerLightPresentation.flickerDistance,
                    directionalDot:
                        lastRoom.markerLightPresentation.directionalDot,
                    flags: lastRoom.markerLightPresentation.flags,
                    timebits:
                        lastRoom.markerLightPresentation.timebits,
                    angle: lastRoom.markerLightPresentation.angle,
                    lightingRenderType:
                        lastRoom.markerLightPresentation
                            .lightingRenderType
                ),
                openMarkerLightDistance:
                    lastRoom.openMarkerLightDistance,
                timerDuration: lastRoom.timerDuration,
                completionMessages: lastRoom.completionMessages,
                completionVoiceSourceName:
                    lastRoom.completionVoiceSourceName
            )
        )
        assertValidationError(
            .invalidDependency(
                "Training Script 034 / 049 last-room chain"
            ),
            hostileMarkerPresentation
        )
    }

    func testSchemaElevenValidatesExactTrainingInvulnerabilityPickupChain()
        throws
    {
        let level = makeTrainingInvulnerabilityPickupLevel()
        try level.validate()

        XCTAssertEqual(level.schemaVersion, 11)
        let chain = try XCTUnwrap(
            level.trainingInvulnerabilityPickupChain
        )
        XCTAssertEqual(chain.pickupObjectHandle, 2_076)
        XCTAssertEqual(chain.pickupRoomSourceIndex, 12)
        XCTAssertEqual(chain.pickupObjectFlags, 5_120)
        XCTAssertEqual(chain.duration, 30)
        XCTAssertEqual(chain.activatedMessage, "Invulnerability On")
        XCTAssertEqual(chain.expiredMessage, "Invulnerability Off")
        XCTAssertEqual(chain.pickupSoundSourceName, "Power03.wav")
        XCTAssertEqual(chain.activatedSoundSourceName, "Invon.wav")
        XCTAssertEqual(chain.expiredSoundSourceName, "Invoff.wav")

        let missingPickup = replacing(
            level,
            objects: level.objects.filter { $0.handle != 2_076 },
            objectPresentations: level.objectPresentations.filter {
                $0.objectHandle != 2_076
            }
        )
        assertValidationError(
            .invalidDependency("Training InvulnPowerup2 pickup chain"),
            missingPickup
        )

        let hostileDuration = replacing(
            level,
            trainingInvulnerabilityPickupChain: .init(
                pickupObjectHandle: chain.pickupObjectHandle,
                pickupRoomSourceIndex: chain.pickupRoomSourceIndex,
                pickupObjectFlags: chain.pickupObjectFlags,
                pickupCollisionRadius: chain.pickupCollisionRadius,
                duration: 29,
                activatedMessage: chain.activatedMessage,
                expiredMessage: chain.expiredMessage,
                pickupSoundSourceName: chain.pickupSoundSourceName,
                activatedSoundSourceName:
                    chain.activatedSoundSourceName,
                expiredSoundSourceName: chain.expiredSoundSourceName
            )
        )
        assertValidationError(
            .invalidDependency("Training InvulnPowerup2 pickup chain"),
            hostileDuration
        )
    }
    func testSchemaNineRejectsHostileTrainingLessonAndVoiceMutations() throws {
        let base = makeSliceSixObjectRenderLevel()
        let archive = "missions/training.mn3"
        let stockSource = replacing(
            base.source,
            profileIdentifier: "descent3.cd-1.4-mercenary.training.v1",
            archiveSHA256:
                "fc1d81921cc4b2618e441b7b9d08c4bcb5cff90731be1bfa6f3a7b054fc0cb54",
            levelSHA256:
                "915a561cd3bd720d88bffed72fe41b4ff711c287711f060ecd9696e2cd5f7d41"
        )
        let stockBase = replacing(
            base,
            missionKey: "descent3.mission.pilot-training",
            levelKey: "descent3.level.training-mission",
            source: stockSource
        )
        let goalHandle: UInt32 = 12_301
        let lesson = TrainingOpeningLesson(
            forwardGoalObjectHandle: goalHandle,
            welcomeDelay: 1,
            welcomeMessage: "Welcome",
            forwardInstruction: "Forward",
            welcomeVoiceSourceName: "welcome.osf",
            successMessage: "Excellent",
            reverseInstruction: "Reverse",
            successVoiceSourceName: "return1.osf"
        )
        let clips = [
            CanonicalVoiceClip(
                sourceName: "welcome.osf",
                sourceEntryIndex: 38,
                sampleRate: 22_050,
                channelCount: 1,
                frameCount: 1,
                pcm16LittleEndian: Data(repeating: 0, count: 2),
                pcmSHA256: canonicalSHA256(Data(repeating: 0, count: 2)),
                sourceArchive: archive,
                sourceSHA256:
                    "35e31517adb824f3637b877d500e12625b99d1a7044a2ce743087505c88ece36"
            ),
            CanonicalVoiceClip(
                sourceName: "return1.osf",
                sourceEntryIndex: 28,
                sampleRate: 22_050,
                channelCount: 1,
                frameCount: 1,
                pcm16LittleEndian: Data(repeating: 0, count: 2),
                pcmSHA256: canonicalSHA256(Data(repeating: 0, count: 2)),
                sourceArchive: archive,
                sourceSHA256:
                    "048067398846141f61a2d503f6ec582f0dbbc5f3bf3feead48047eab808e540f"
            ),
        ]
        let voiceDependencies = clips.map {
            DependencyRecord(
                category: "voice",
                source: .init(
                    storedIndex: $0.sourceEntryIndex,
                    sourceName: $0.sourceName
                ),
                state: "canonical-pcm-imported",
                provenance: "test"
            )
        }
        assertValidationError(
            .invalidDependency("Training opening package"),
            stockBase
        )
        assertValidationError(
            .invalidDependency("Training opening package"),
            replacing(
                stockBase,
                source: replacing(
                    stockSource,
                    profileIdentifier: "hostile.renamed-profile"
                )
            )
        )
        assertValidationError(
            .invalidDependency("Training opening package"),
            replacing(
                stockBase,
                missionKey: "hostile.renamed-mission",
                levelKey: "hostile.renamed-level"
            )
        )
        let level = stockBase.addingTrainingOpeningLesson(
            lesson,
            voiceClips: clips
        )
        assertValidationError(
            .invalidDependency("Training opening package"),
            level
        )
        var wrongStockHash = clips
        wrongStockHash[0] = CanonicalVoiceClip(
            sourceName: clips[0].sourceName,
            sourceEntryIndex: clips[0].sourceEntryIndex,
            sampleRate: clips[0].sampleRate,
            channelCount: clips[0].channelCount,
            frameCount: clips[0].frameCount,
            pcm16LittleEndian: clips[0].pcm16LittleEndian,
            pcmSHA256: clips[0].pcmSHA256,
            sourceArchive: clips[0].sourceArchive,
            sourceSHA256: String(repeating: "d", count: 64)
        )
        assertValidationError(
            .invalidDependency("Training opening package"),
            replacing(level, voiceClips: wrongStockHash)
        )
        var wrongStockIndex = clips
        wrongStockIndex[0] = CanonicalVoiceClip(
            sourceName: clips[0].sourceName,
            sourceEntryIndex: 39,
            sampleRate: clips[0].sampleRate,
            channelCount: clips[0].channelCount,
            frameCount: clips[0].frameCount,
            pcm16LittleEndian: clips[0].pcm16LittleEndian,
            pcmSHA256: clips[0].pcmSHA256,
            sourceArchive: clips[0].sourceArchive,
            sourceSHA256: clips[0].sourceSHA256
        )
        let wrongStockDependencies = wrongStockIndex.map {
            DependencyRecord(
                category: "voice",
                source: .init(
                    storedIndex: $0.sourceEntryIndex,
                    sourceName: $0.sourceName
                ),
                state: "canonical-pcm-imported",
                provenance: "test"
            )
        }
        assertValidationError(
            .invalidDependency("Training opening package"),
            replacing(
                level,
                voiceClips: wrongStockIndex,
                dependencyManifest: .init(
                    current: base.dependencyManifest.current
                        + wrongStockDependencies,
                    historicalEagerBaseline:
                        base.dependencyManifest.historicalEagerBaseline
                )
            )
        )
        var visiblePresentations = level.objectPresentations
        let goalPresentationIndex = try XCTUnwrap(
            visiblePresentations.firstIndex {
                $0.objectHandle == lesson.forwardGoalObjectHandle
            }
        )
        let hiddenGoal = visiblePresentations[goalPresentationIndex]
        visiblePresentations[goalPresentationIndex] = ObjectPresentationReference(
            objectHandle: hiddenGoal.objectHandle,
            primaryModel: hiddenGoal.primaryModel,
            mediumModel: hiddenGoal.mediumModel,
            lowModel: hiddenGoal.lowModel,
            dyingModel: hiddenGoal.dyingModel,
            mediumDistance: hiddenGoal.mediumDistance,
            lowDistance: hiddenGoal.lowDistance,
            isVisible: true
        )
        assertValidationError(
            .invalidDependency("Training opening lesson"),
            replacing(level, objectPresentations: visiblePresentations)
        )

        var missingTarget = lesson
        missingTarget.forwardGoalObjectHandle = 999_999
        assertValidationError(
            .invalidDependency("Training opening lesson"),
            replacing(level, trainingOpeningLesson: missingTarget)
        )
        assertValidationError(
            .invalidDependency("Training opening lesson"),
            replacing(
                level,
                trainingOpeningLesson: .init(
                    forwardGoalObjectHandle: lesson.forwardGoalObjectHandle,
                    welcomeDelay: lesson.welcomeDelay,
                    welcomeMessage: lesson.welcomeMessage,
                    forwardInstruction: lesson.forwardInstruction,
                    welcomeVoiceSourceName: "missing.osf",
                    successMessage: lesson.successMessage,
                    reverseInstruction: lesson.reverseInstruction,
                    successVoiceSourceName: lesson.successVoiceSourceName
                )
            )
        )
        var malformedClips = clips
        malformedClips[0] = CanonicalVoiceClip(
            sourceName: clips[0].sourceName,
            sourceEntryIndex: clips[0].sourceEntryIndex,
            sampleRate: clips[0].sampleRate,
            channelCount: clips[0].channelCount,
            frameCount: 2,
            pcm16LittleEndian: clips[0].pcm16LittleEndian,
            pcmSHA256: clips[0].pcmSHA256,
            sourceArchive: clips[0].sourceArchive,
            sourceSHA256: clips[0].sourceSHA256
        )
        assertValidationError(
            .invalidDependency("Canonical voice clip"),
            replacing(level, voiceClips: malformedClips)
        )
        var invalidProvenance = clips
        invalidProvenance[0] = CanonicalVoiceClip(
            sourceName: clips[0].sourceName,
            sourceEntryIndex: clips[0].sourceEntryIndex,
            sampleRate: clips[0].sampleRate,
            channelCount: clips[0].channelCount,
            frameCount: clips[0].frameCount,
            pcm16LittleEndian: clips[0].pcm16LittleEndian,
            pcmSHA256: clips[0].pcmSHA256,
            sourceArchive: clips[0].sourceArchive,
            sourceSHA256: "invalid"
        )
        assertValidationError(
            .invalidDependency("Canonical voice clip"),
            replacing(level, voiceClips: invalidProvenance)
        )
        assertValidationError(
            .invalidDependency("Canonical voice clip"),
            replacing(
                level,
                dependencyManifest: .init(
                    current: base.dependencyManifest.current
                        + Array(voiceDependencies.dropFirst()),
                    historicalEagerBaseline:
                        base.dependencyManifest.historicalEagerBaseline
                )
            )
        )
    }

    func testSchemaNineRejectsHostileRobotGuidebotStockIdentities() throws {
        let chain = TrainingRobotGuidebotChain(
            destroyRobotObjectHandle: 4_112,
            guidebotObjectHandle: 6_164,
            destroyRobotRoomSourceIndex: 37,
            destroyRobotFlags: 5_121,
            destructionDelay: 2,
            destructionMessage: "Excellent!",
            exitInstruction:
                "Now go through the open doorway, and into the next room.",
            destructionVoiceSourceName: "proceed5.osf",
            deployedGuidebotObjectType: 2,
            deployedGuidebotMessage:
                "Have the Guidebot help you complete a goal.  Press F4 and select item 1.  Fly over the object he leads you to.",
            deployedGuidebotVoiceSourceName: "guidebotb.osf",
            combat: .stockTraining,
            guidebot: .stockTraining
        )
        func clip(
            name: String,
            index: Int,
            frames: Int,
            pcmSHA256: String,
            sourceSHA256: String
        ) -> CanonicalVoiceClip {
            CanonicalVoiceClip(
                sourceName: name,
                sourceEntryIndex: index,
                sampleRate: 22_050,
                channelCount: 1,
                frameCount: frames,
                pcm16LittleEndian: Data(),
                pcmSHA256: pcmSHA256,
                sourceArchive: "missions/training.mn3",
                sourceSHA256: sourceSHA256
            )
        }
        let guidebotB = clip(
            name: "guidebotb.osf",
            index: 5,
            frames: 299_701,
            pcmSHA256:
                "11ac67df4f4fe234104ca32b97299539e590a6e6d7a826e85d3c1a10ccc52fe4",
            sourceSHA256:
                "0238e793083d875d233d18eaf018aa4526d34cf0c6bed0e659e4725ff8c7ffda"
        )
        let proceed5 = clip(
            name: "proceed5.osf",
            index: 25,
            frames: 136_341,
            pcmSHA256:
                "3ec85db25577616344f6289a319ad01b8fa6406e49f4452ef39f268ddf830490",
            sourceSHA256:
                "4bbb54d28b38ae48d665e16493c67a82c59ec213c23527a100aa67db671c477c"
        )

        XCTAssertNoThrow(
            try validateStockTrainingRobotGuidebotPackage(
                chain: chain,
                guidebotB: guidebotB,
                proceed5: proceed5
            )
        )
        let buddyModel = SourceResource(
            storedIndex: 1,
            sourceName: "Buddybot.oof"
        )
        let destroyRobotModel = SourceResource(
            storedIndex: 2,
            sourceName: "gyro.oof"
        )
        let destroyRobotPresentation = ObjectPresentationReference(
            objectHandle: 4_112,
            primaryModel: destroyRobotModel,
            mediumModel: nil,
            lowModel: nil,
            dyingModel: nil,
            mediumDistance: nil,
            lowDistance: nil
        )
        let guidebotObject = PlacedObject(
            handle: chain.guidebotObjectHandle,
            type: 2,
            storedID: 0,
            definition: .init(storedIndex: 0, sourceName: "GuideBot"),
            instanceName: "GuideBotB",
            flags: 0x110f,
            doorShields: nil,
            location: .room(37),
            position: .zero,
            orientation: .init(
                right: .init(x: 1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: 0),
                forward: .init(x: 0, y: 0, z: 1)
            ),
            containsType: 0,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: nil,
            inertScriptName: nil,
            inertModuleName: nil,
            lightmapSubmodels: []
        )
        let guidebotPresentation = ObjectPresentationReference(
            objectHandle: chain.guidebotObjectHandle,
            primaryModel: buddyModel,
            mediumModel: nil,
            lowModel: nil,
            dyingModel: nil,
            mediumDistance: nil,
            lowDistance: nil,
            isVisible: false
        )
        XCTAssertNoThrow(
            try validateStockTrainingRobotGuidebotPresentation(
                chain: chain,
                modelSources: [buddyModel, destroyRobotModel],
                objects: [guidebotObject],
                objectPresentations: [
                    destroyRobotPresentation,
                    guidebotPresentation,
                ]
            )
        )
        for (modelSources, objectPresentations) in [
            (
                [destroyRobotModel],
                [destroyRobotPresentation, guidebotPresentation]
            ),
            (
                [buddyModel],
                [destroyRobotPresentation, guidebotPresentation]
            ),
            ([buddyModel, destroyRobotModel], []),
        ] {
            XCTAssertThrowsError(
                try validateStockTrainingRobotGuidebotPresentation(
                    chain: chain,
                    modelSources: modelSources,
                    objects: [guidebotObject],
                    objectPresentations: objectPresentations
                )
            ) {
                XCTAssertEqual(
                    $0 as? LevelValidationError,
                    .invalidDependency(
                        "Training robot and Guidebot presentation"
                    )
                )
            }
        }

        let hostileChain = TrainingRobotGuidebotChain(
            destroyRobotObjectHandle: chain.destroyRobotObjectHandle,
            guidebotObjectHandle: chain.guidebotObjectHandle,
            destroyRobotRoomSourceIndex: 38,
            destroyRobotFlags: chain.destroyRobotFlags,
            destructionDelay: chain.destructionDelay,
            destructionMessage: chain.destructionMessage,
            exitInstruction: chain.exitInstruction,
            destructionVoiceSourceName: chain.destructionVoiceSourceName,
            deployedGuidebotObjectType: chain.deployedGuidebotObjectType,
            deployedGuidebotMessage: chain.deployedGuidebotMessage,
            deployedGuidebotVoiceSourceName:
                chain.deployedGuidebotVoiceSourceName,
            combat: chain.combat,
            guidebot: chain.guidebot
        )
        XCTAssertThrowsError(
            try validateStockTrainingRobotGuidebotPackage(
                chain: hostileChain,
                guidebotB: guidebotB,
                proceed5: proceed5
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training robot and Guidebot package")
            )
        }

        let hostileCombatChain = TrainingRobotGuidebotChain(
            destroyRobotObjectHandle: chain.destroyRobotObjectHandle,
            guidebotObjectHandle: chain.guidebotObjectHandle,
            destroyRobotRoomSourceIndex:
                chain.destroyRobotRoomSourceIndex,
            destroyRobotFlags: chain.destroyRobotFlags,
            destructionDelay: chain.destructionDelay,
            destructionMessage: chain.destructionMessage,
            exitInstruction: chain.exitInstruction,
            destructionVoiceSourceName: chain.destructionVoiceSourceName,
            deployedGuidebotObjectType: chain.deployedGuidebotObjectType,
            deployedGuidebotMessage: chain.deployedGuidebotMessage,
            deployedGuidebotVoiceSourceName:
                chain.deployedGuidebotVoiceSourceName,
            combat: .init(
                robotShields: 55,
                robotCollisionRadius: chain.combat.robotCollisionRadius,
                batteryEnergyCost: chain.combat.batteryEnergyCost,
                batteryFireWait: chain.combat.batteryFireWait,
                gunpoints: chain.combat.gunpoints,
                projectileSourceName:
                    chain.combat.projectileSourceName,
                projectileDamage: 8,
                projectileRadius: chain.combat.projectileRadius,
                projectileSpeed: chain.combat.projectileSpeed,
                projectileLifetime: chain.combat.projectileLifetime
            ),
            guidebot: chain.guidebot
        )
        XCTAssertThrowsError(
            try validateStockTrainingRobotGuidebotPackage(
                chain: hostileCombatChain,
                guidebotB: guidebotB,
                proceed5: proceed5
            )
        )

        let hostileVoicePairs = [
            (
                clip(
                    name: "guidebotb.osf",
                    index: 6,
                    frames: 299_701,
                    pcmSHA256: guidebotB.pcmSHA256,
                    sourceSHA256: guidebotB.sourceSHA256
                ),
                proceed5
            ),
            (
                clip(
                    name: "guidebotb.osf",
                    index: 5,
                    frames: 299_701,
                    pcmSHA256: String(repeating: "0", count: 64),
                    sourceSHA256: guidebotB.sourceSHA256
                ),
                proceed5
            ),
            (
                guidebotB,
                clip(
                    name: "proceed5.osf",
                    index: 24,
                    frames: 136_341,
                    pcmSHA256: proceed5.pcmSHA256,
                    sourceSHA256: proceed5.sourceSHA256
                )
            ),
            (
                guidebotB,
                clip(
                    name: "proceed5.osf",
                    index: 25,
                    frames: 136_341,
                    pcmSHA256: proceed5.pcmSHA256,
                    sourceSHA256: String(repeating: "0", count: 64)
                )
            ),
        ]
        for (hostileGuidebotB, hostileProceed5) in hostileVoicePairs {
            XCTAssertThrowsError(
                try validateStockTrainingRobotGuidebotPackage(
                    chain: chain,
                    guidebotB: hostileGuidebotB,
                    proceed5: hostileProceed5
                )
            ) {
                XCTAssertEqual(
                    $0 as? LevelValidationError,
                    .invalidDependency("Training robot and Guidebot package")
                )
            }
        }
    }

    func testSchemaTenRejectsHostileCameraMonitorVoiceFormatAndArchive() throws {
        let fixture = makeTrainingCameraMonitorLevel()
        let chain = TrainingCameraMonitorChain(
            pickupObjectHandle: 6_167,
            securityCameraObjectHandle: 6_183,
            pickupCollisionRadius: 3.682_004,
            pickupMessage:
                "Excellent.  You now have the Camera Monitor.  Press the Use Inventory key to activate it!",
            pickupVoiceSourceName: "guidebotc.osf",
            pickupSoundSourceName: "PupC.wav",
            useMessage:
                "Now recall the Guidebot by pressing F4 and selecting \"Return to Ship\".  Move to the next area when he returns.",
            useVoiceSourceName: "guidebotd.osf",
            popupDuration: 10,
            popupZoom: 1,
            cameraGunpointIndex: 0,
            cameraLocalPosition: .init(
                x: -0.092_777_25,
                y: 0.791_976,
                z: 5.571_280_5
            ),
            cameraLocalForward: .init(
                x: -2.880_202e-7,
                y: -0.017_452_003,
                z: 0.999_847_7
            ),
            completionTimerDuration: 2,
            returnToShip: .init(
                markerLightObjectHandle: 10_245,
                markerLightPresentation: .init(
                    primaryColor: .init(x: 1, y: 0.25, z: 0),
                    secondaryColor: .zero,
                    timeInterval: 0.5,
                    flickerDistance: 0.2,
                    directionalDot: 0,
                    flags: 4,
                    timebits: .max,
                    angle: 0,
                    lightingRenderType: 2
                ),
                barrierRoomSourceIndex: 40,
                orderedPortalIndices: [0, 1],
                openMarkerLightDistance: 50,
                returnMessage: "GB: Returning to ship.",
                returnSoundSourceName: "GBotAcceptOrder.wav",
                greetingSoundSourceName: "GBotGreetB.wav",
                arrivalMessage: "GB: Entering ship!",
                successMessage: "Excellent!",
                successVoiceSourceName: "proceed6.osf",
                killbotEntry: .init(
                    triggerName: "Portal3",
                    triggerRoomSourceIndex: 40,
                    triggerFaceIndex: 1,
                    orderedPortalIndices: [1, 0],
                    closedMarkerLightDistance: 0,
                    entryMessage:
                        "Now you are on your own in this room. There are 4 robots and 2 powerups. Get the powerups and kill the robots.",
                    entryVoiceSourceName: "intro6.osf",
                    followupDelay: 13,
                    followupMessage:
                        "Some parts of this area are very dark.  Turn on your headlight or fire flares to see.  Use your guidebot if you need help finding a robot or powerup.",
                    followupVoiceSourceName: "guidebotf.osf"
                )
            )
        )
        func voice(
            name: String,
            index: Int,
            frames: Int,
            pcmSHA256: String,
            sourceSHA256: String,
            sampleRate: Int = 22_050,
            channelCount: Int = 1,
            sourceArchive: String = "missions/training.mn3"
        ) -> CanonicalVoiceClip {
            CanonicalVoiceClip(
                sourceName: name,
                sourceEntryIndex: index,
                sampleRate: sampleRate,
                channelCount: channelCount,
                frameCount: frames,
                pcm16LittleEndian: Data(),
                pcmSHA256: pcmSHA256,
                sourceArchive: sourceArchive,
                sourceSHA256: sourceSHA256
            )
        }
        let guidebotC = voice(
            name: "guidebotc.osf",
            index: 6,
            frames: 273_181,
            pcmSHA256:
                "b5d968ac310d7d95780f2abd58933e7fdce20d284a9ef614e18e9f8eea3e18de",
            sourceSHA256:
                "20d0d1e82f56c7c4d326788ac9caa1dc39ec81d4a022be52967776ec5fa85dc1"
        )
        let guidebotD = voice(
            name: "guidebotd.osf",
            index: 7,
            frames: 149_653,
            pcmSHA256:
                "d97e6efaa106fbe9c4dff0affe155e04db18938e842be494292d0008b10f2a71",
            sourceSHA256:
                "afffa8e1a39b1c6e8956105c52db8fa372a33b763aa44e18980f2e22884795d1"
        )
        let proceed6 = voice(
            name: "proceed6.osf",
            index: 26,
            frames: 141_237,
            pcmSHA256:
                "ccc21ee44f4e965806904dfbd4aa95be1510e8cbe633ab43f0808b7f3026b06d",
            sourceSHA256:
                "b3cd5455401af0f387d8cde20c3c869897aef55070cf8cfadd141c0f291bc403"
        )
        let intro6 = voice(
            name: "intro6.osf",
            index: 15,
            frames: 212_125,
            pcmSHA256:
                "5ee0e98d12a0648b8ce0e239ff5df36da37b4e9d6634a846d6a91fa849a1cf79",
            sourceSHA256:
                "e8e955dd608942543f5442d1c187018286ea060fcc7440a4e180df24e602fc4a"
        )
        let guidebotF = voice(
            name: "guidebotf.osf",
            index: 9,
            frames: 91_221,
            pcmSHA256:
                "244adc2baaeab1ccdf69a676a4b7cb5b81561db53a1fce1f50bd9b899c077c49",
            sourceSHA256:
                "bc15f7be1b1a9203d1fbc264649d9d8b23d24daf522df70c9460e9007904e2f2"
        )
        let pickupSound = CanonicalSoundClip(
            logicalName: "PupC1",
            sourceName: "PupC.wav",
            sourceEntryIndex: 130,
            sampleRate: 22_050,
            channelCount: 1,
            frameCount: 16_759,
            pcm16LittleEndian: Data(),
            pcmSHA256:
                "6cc9a2c4853f3575838d8ef16f51847e4c990140d5206158a582abddf130f099",
            sourceArchive: "d3.hog",
            sourceSHA256:
                "d3e8e7515facfd6c1b540e70cf7f1019c3d1f13f24140bee76337e5bb37de7d0",
            importVolume: 1
        )
        let returnSound = CanonicalSoundClip(
            logicalName: "GBotAcceptOrder1",
            sourceName: "GBotAcceptOrder.wav",
            sourceEntryIndex: 1_257,
            sampleRate: 22_050,
            channelCount: 1,
            frameCount: 21_652,
            pcm16LittleEndian: Data(),
            pcmSHA256:
                "d1d068fbd7950adeaffe5a2cf3c6c56b59d488f9c53b3460f88adfb7178183b1",
            sourceArchive: "d3.hog",
            sourceSHA256:
                "47e38dfcb285be1b8d19d59929fef1b1122c1772a0cca2e6fe2b1721e5876b17",
            importVolume: 0.45
        )
        let greetingSound = CanonicalSoundClip(
            logicalName: "GBotGreetB1",
            sourceName: "GBotGreetB.wav",
            sourceEntryIndex: 1_268,
            sampleRate: 22_050,
            channelCount: 1,
            frameCount: 16_046,
            pcm16LittleEndian: Data(),
            pcmSHA256:
                "ec585e440bb7cc07550cd9402b6b1dc69831dd00ade8052572a5cb2383fcb2fe",
            sourceArchive: "d3.hog",
            sourceSHA256:
                "5e2aee56e77e39592295759705671c37259ff8ca8cc9357ebac1bb38d7c004ca",
            importVolume: 1
        )
        let presentation = ObjectPresentationReference(
            objectHandle: 6_167,
            primaryModel: .init(
                storedIndex: 0,
                sourceName: "camerapowerup.OOF"
            ),
            mediumModel: nil,
            lowModel: nil,
            dyingModel: nil,
            mediumDistance: nil,
            lowDistance: nil
        )
        let stockObjects = fixture.objects.map { object in
            guard object.handle == 10_245 else { return object }
            var marker = object
            marker.location = .room(40)
            return marker
        }
        func validate(
            guidebotC: CanonicalVoiceClip,
            guidebotD: CanonicalVoiceClip,
            intro6Override: CanonicalVoiceClip? = nil
        ) throws {
            try validateStockTrainingCameraMonitorPackage(
                chain: chain,
                guidebotC: guidebotC,
                guidebotD: guidebotD,
                proceed6: proceed6,
                intro6: intro6Override ?? intro6,
                guidebotF: guidebotF,
                pickupSound: pickupSound,
                returnSound: returnSound,
                greetingSound: greetingSound,
                objects: stockObjects,
                objectPresentations: [presentation]
            )
        }

        XCTAssertNoThrow(
            try validate(guidebotC: guidebotC, guidebotD: guidebotD)
        )
        let hostileReturnSound = CanonicalSoundClip(
            logicalName: returnSound.logicalName,
            sourceName: returnSound.sourceName,
            sourceEntryIndex: 180,
            sampleRate: returnSound.sampleRate,
            channelCount: returnSound.channelCount,
            frameCount: returnSound.frameCount,
            pcm16LittleEndian: returnSound.pcm16LittleEndian,
            pcmSHA256: returnSound.pcmSHA256,
            sourceArchive: returnSound.sourceArchive,
            sourceSHA256: returnSound.sourceSHA256,
            importVolume: returnSound.importVolume
        )
        XCTAssertThrowsError(
            try validateStockTrainingCameraMonitorPackage(
                chain: chain,
                guidebotC: guidebotC,
                guidebotD: guidebotD,
                proceed6: proceed6,
                pickupSound: pickupSound,
                returnSound: hostileReturnSound,
                greetingSound: greetingSound,
                objects: stockObjects,
                objectPresentations: [presentation]
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training Camera Monitor package")
            )
        }
        let hostileGreetingSound = CanonicalSoundClip(
            logicalName: greetingSound.logicalName,
            sourceName: greetingSound.sourceName,
            sourceEntryIndex: greetingSound.sourceEntryIndex,
            sampleRate: greetingSound.sampleRate,
            channelCount: greetingSound.channelCount,
            frameCount: greetingSound.frameCount,
            pcm16LittleEndian: greetingSound.pcm16LittleEndian,
            pcmSHA256: greetingSound.pcmSHA256,
            sourceArchive: greetingSound.sourceArchive,
            sourceSHA256: String(repeating: "0", count: 64),
            importVolume: greetingSound.importVolume
        )
        XCTAssertThrowsError(
            try validateStockTrainingCameraMonitorPackage(
                chain: chain,
                guidebotC: guidebotC,
                guidebotD: guidebotD,
                proceed6: proceed6,
                intro6: intro6,
                guidebotF: guidebotF,
                pickupSound: pickupSound,
                returnSound: returnSound,
                greetingSound: hostileGreetingSound,
                objects: stockObjects,
                objectPresentations: [presentation]
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training Camera Monitor package")
            )
        }
        let hostileIntro6 = voice(
            name: intro6.sourceName,
            index: intro6.sourceEntryIndex + 1,
            frames: intro6.frameCount,
            pcmSHA256: intro6.pcmSHA256,
            sourceSHA256: intro6.sourceSHA256
        )
        XCTAssertThrowsError(
            try validate(
                guidebotC: guidebotC,
                guidebotD: guidebotD,
                intro6Override: hostileIntro6
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training Camera Monitor package")
            )
        }
        let hostilePairs = [
            (
                voice(
                    name: "guidebotc.osf",
                    index: 6,
                    frames: 273_181,
                    pcmSHA256: guidebotC.pcmSHA256,
                    sourceSHA256: guidebotC.sourceSHA256,
                    sampleRate: 44_100
                ),
                guidebotD
            ),
            (
                voice(
                    name: "guidebotc.osf",
                    index: 6,
                    frames: 273_181,
                    pcmSHA256: guidebotC.pcmSHA256,
                    sourceSHA256: guidebotC.sourceSHA256,
                    channelCount: 2
                ),
                guidebotD
            ),
            (
                guidebotC,
                voice(
                    name: "guidebotd.osf",
                    index: 7,
                    frames: 149_653,
                    pcmSHA256: guidebotD.pcmSHA256,
                    sourceSHA256: guidebotD.sourceSHA256,
                    sourceArchive: "hostile/training.mn3"
                )
            ),
        ]
        for (hostileGuidebotC, hostileGuidebotD) in hostilePairs {
            XCTAssertThrowsError(
                try validate(
                    guidebotC: hostileGuidebotC,
                    guidebotD: hostileGuidebotD
                )
            ) {
                XCTAssertEqual(
                    $0 as? LevelValidationError,
                    .invalidDependency("Training Camera Monitor package")
                )
            }
        }
    }

    func testSchemaTenRejectsPartialGuidebotReturnBarrierState() throws {
        var level = makeTrainingCameraMonitorLevel()
        try level.validate()
        let barrier = try XCTUnwrap(
            level.trainingCameraMonitorChain?.returnToShip
        )
        let roomIndex = try XCTUnwrap(level.rooms.firstIndex {
            $0.sourceIndex == barrier.barrierRoomSourceIndex
        })
        let portalIndex = barrier.orderedPortalIndices[0]
        level.rooms[roomIndex].portals[portalIndex].flags ^= 1

        XCTAssertFalse(
            validTrainingGuidebotReturnBarrier(barrier, in: level)
        )
        XCTAssertThrowsError(try level.validate()) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training gallery barrier")
            )
        }
    }

    func testSchemaTenRejectsNonForceFieldGuidebotReturnBarrierFace()
        throws
    {
        var level = makeTrainingCameraMonitorLevel()
        try level.validate()
        let barrier = try XCTUnwrap(
            level.trainingCameraMonitorChain?.returnToShip
        )
        let roomIndex = try XCTUnwrap(level.rooms.firstIndex {
            $0.sourceIndex == barrier.barrierRoomSourceIndex
        })
        let portalIndex = barrier.orderedPortalIndices[0]
        let faceIndex = level.rooms[roomIndex]
            .portals[portalIndex].faceIndex
        let presentedTextures = Set(
            level.presentationMaterials.map(\.texture)
        )
        let ordinaryTexture = try XCTUnwrap(
            level.surfacePhysics.first {
                $0.behavior != .forceField
                    && presentedTextures.contains($0.texture)
            }?.texture
        )
        level.rooms[roomIndex].faces[faceIndex].texture =
            ordinaryTexture

        XCTAssertFalse(
            validTrainingGuidebotReturnBarrier(barrier, in: level)
        )
        XCTAssertThrowsError(try level.validate()) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training gallery barrier")
            )
        }
    }

    func testSchemaTenRejectsAlternateForceFieldGuidebotReturnBarrier()
        throws
    {
        var level = makeTrainingCameraMonitorLevel()
        try level.validate()
        let barrier = try XCTUnwrap(
            level.trainingCameraMonitorChain?.returnToShip
        )
        let sourceMaterial = try XCTUnwrap(
            level.presentationMaterials.first {
                $0.texture
                    == SourceResource(
                        storedIndex: 908,
                        sourceName: "Alien Force Field_1"
                    )
            }
        )
        let alternateTexture = SourceResource(
            storedIndex: 909,
            sourceName: "Alien Force Field Alternate"
        )
        let surfacePhysics = level.surfacePhysics + [.init(
            texture: alternateTexture,
            behavior: .forceField
        )]
        let presentationMaterials = level.presentationMaterials + [.init(
            texture: alternateTexture,
            bitmapSourceName: "alternate-force-field.ogf",
            image: sourceMaterial.image,
            blend: sourceMaterial.blend,
            lightmapBlend: sourceMaterial.lightmapBlend,
            waterProcedural: sourceMaterial.waterProcedural,
            sourceArchive: sourceMaterial.sourceArchive,
            sourceSHA256: String(repeating: "9", count: 64)
        )]
        let dependencyManifest = DependencyManifest(
            current: level.dependencyManifest.current + [
                .init(
                    category: "texture",
                    source: alternateTexture,
                    state: "presentation-payload-imported",
                    provenance: "hostile alternate force-field fixture"
                ),
            ],
            historicalEagerBaseline:
                level.dependencyManifest.historicalEagerBaseline
        )
        let roomIndex = try XCTUnwrap(level.rooms.firstIndex {
            $0.sourceIndex == barrier.barrierRoomSourceIndex
        })
        for portalIndex in barrier.orderedPortalIndices.prefix(1) {
            let portal = level.rooms[roomIndex].portals[portalIndex]
            level.rooms[roomIndex].faces[portal.faceIndex].texture =
                alternateTexture
            let reciprocalRoomIndex = try XCTUnwrap(
                level.rooms.firstIndex {
                    $0.sourceIndex == portal.connectedRoom
                }
            )
            let reciprocal = level.rooms[reciprocalRoomIndex]
                .portals[portal.connectedPortal]
            level.rooms[reciprocalRoomIndex]
                .faces[reciprocal.faceIndex].texture =
                alternateTexture
        }
        level = replacing(
            level,
            rooms: level.rooms,
            surfacePhysics: surfacePhysics,
            presentationMaterials: presentationMaterials,
            dependencyManifest: dependencyManifest
        )

        XCTAssertFalse(
            validTrainingGuidebotReturnBarrier(barrier, in: level)
        )
        XCTAssertThrowsError(try level.validate()) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training Camera Monitor chain")
            )
        }
    }

    func testSchemaTenRejectsInvalidKillbotEntryTimer() throws {
        let level = makeTrainingKillbotEntryLevel(followupDelay: 0)

        XCTAssertThrowsError(try level.validate()) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training Camera Monitor chain")
            )
        }
    }

    func testSchemaElevenDefaultsMissingGuidebotGreetingBinding()
        throws
    {
        let level = makeTrainingRASBot1DeathLevel()
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(level)
            ) as? [String: Any]
        )
        var camera = try XCTUnwrap(
            object["trainingCameraMonitorChain"]
                as? [String: Any]
        )
        var returnChain = try XCTUnwrap(
            camera["returnToShip"] as? [String: Any]
        )
        returnChain.removeValue(
            forKey: "greetingSoundSourceName"
        )
        camera["returnToShip"] = returnChain
        object["trainingCameraMonitorChain"] = camera

        let decoded = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertEqual(decoded.schemaVersion, 11)
        XCTAssertNil(
            decoded.trainingCameraMonitorChain?.returnToShip?
                .greetingSoundSourceName
        )
        XCTAssertNoThrow(try decoded.validate())
    }

    func testOwnedGuidebotGreetingPackagePinsCoupledSoundBoundary()
        throws
    {
        let path = try XCTUnwrap(
            ProcessInfo.processInfo.environment[
                "REVIVAL_GUIDEBOT_GREETING_OWNED_LEVEL"
            ],
            "requires the ignored exact-final owned Guidebot level"
        )
        let level = try JSONDecoder().decode(
            Level.self,
            from: Data(contentsOf: URL(fileURLWithPath: path))
        )
        XCTAssertNoThrow(try level.validate())
        XCTAssertEqual(
            level.trainingCameraMonitorChain?.returnToShip?
                .greetingSoundSourceName,
            "GBotGreetB.wav"
        )
        let greeting = try XCTUnwrap(level.soundClips.first {
            $0.logicalName == "GBotGreetB1"
        })
        XCTAssertEqual(greeting.sourceName, "GBotGreetB.wav")
        XCTAssertEqual(greeting.sourceEntryIndex, 1_268)
        XCTAssertEqual(greeting.sampleRate, 22_050)
        XCTAssertEqual(greeting.channelCount, 1)
        XCTAssertEqual(greeting.frameCount, 16_046)
        XCTAssertEqual(greeting.importVolume, 1)
        XCTAssertEqual(
            greeting.sourceSHA256,
            "5e2aee56e77e39592295759705671c37259ff8ca8cc9357ebac1bb38d7c004ca"
        )
        XCTAssertEqual(
            greeting.pcmSHA256,
            "ec585e440bb7cc07550cd9402b6b1dc69831dd00ade8052572a5cb2383fcb2fe"
        )

        var hostileObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(level)
            ) as? [String: Any]
        )
        var sounds = try XCTUnwrap(
            hostileObject["soundClips"] as? [[String: Any]]
        )
        let greetingIndex = try XCTUnwrap(sounds.firstIndex {
            ($0["logicalName"] as? String) == "GBotGreetB1"
        })
        sounds[greetingIndex]["sourceSHA256"] =
            String(repeating: "0", count: 64)
        hostileObject["soundClips"] = sounds
        let hostile = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(
                withJSONObject: hostileObject
            )
        )
        XCTAssertThrowsError(try hostile.validate()) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training Camera Monitor package")
            )
        }
    }

    func testSchemaElevenRequiresExactRASBot1DeathProducer() throws {
        let level = makeTrainingRASBot1DeathLevel()
        try level.validate()
        XCTAssertEqual(level.schemaVersion, 11)

        let chain = try XCTUnwrap(level.trainingRASBot1DeathChain)
        XCTAssertEqual(chain.robotObjectHandle, 2_074)
        XCTAssertEqual(chain.robotRoomSourceIndex, 2)
        XCTAssertEqual(chain.robotFlags, 5_121)
        XCTAssertEqual(chain.combat, .stockTraining)

        let wrongHandle = TrainingRASBot1DeathChain(
            robotObjectHandle: 2_075,
            robotRoomSourceIndex: chain.robotRoomSourceIndex,
            robotFlags: chain.robotFlags,
            combat: chain.combat
        )
        assertValidationError(
            .invalidDependency("Training RASBot1 death chain"),
            replacing(
                level,
                trainingRASBot1DeathChain: wrongHandle
            )
        )
    }

    func testSchemaElevenRequiresExactRASBot2DeathProducer() throws {
        let level = makeTrainingRASBot2DeathLevel()
        try level.validate()
        XCTAssertEqual(level.schemaVersion, 11)
        let chain = try XCTUnwrap(level.trainingRASBot2DeathChain)
        XCTAssertEqual(chain.robotObjectHandle, 2_075)
        XCTAssertEqual(chain.robotRoomSourceIndex, 2)
        XCTAssertEqual(chain.robotFlags, 5_121)
        XCTAssertEqual(chain.combat, .stockTraining)

        let wrongHandle = TrainingRASBot2DeathChain(
            robotObjectHandle: 2_077,
            robotRoomSourceIndex: chain.robotRoomSourceIndex,
            robotFlags: chain.robotFlags,
            combat: chain.combat
        )
        assertValidationError(
            .invalidDependency("Training RASBot2 death chain"),
            level.addingTrainingRASBot2DeathChain(wrongHandle)
        )
    }

    func testSchemaElevenRequiresExactRASBot3DeathProducer() throws {
        let level = makeTrainingRASBot3DeathLevel()
        try level.validate()
        XCTAssertEqual(level.schemaVersion, 11)
        let chain = try XCTUnwrap(level.trainingRASBot3DeathChain)
        XCTAssertEqual(chain.robotObjectHandle, 2_077)
        XCTAssertEqual(chain.robotRoomSourceIndex, 42)
        XCTAssertEqual(chain.robotFlags, 5_121)
        XCTAssertEqual(chain.combat, .stockTraining)

        let wrongHandle = TrainingRASBot3DeathChain(
            robotObjectHandle: 2_078,
            robotRoomSourceIndex: chain.robotRoomSourceIndex,
            robotFlags: chain.robotFlags,
            combat: chain.combat
        )
        assertValidationError(
            .invalidDependency("Training RASBot3 death chain"),
            level.addingTrainingRASBot3DeathChain(wrongHandle)
        )
    }

    func testSchemaElevenRequiresExactRASBot4DeathProducer() throws {
        let level = makeTrainingRASBot4DeathLevel()
        try level.validate()
        XCTAssertEqual(level.schemaVersion, 11)
        let chain = try XCTUnwrap(level.trainingRASBot4DeathChain)
        XCTAssertEqual(chain.robotObjectHandle, 2_078)
        XCTAssertEqual(chain.robotRoomSourceIndex, 0)
        XCTAssertEqual(chain.robotFlags, 5_121)
        XCTAssertEqual(chain.combat, .stockTraining)

        let wrongHandle = TrainingRASBot4DeathChain(
            robotObjectHandle: 2_073,
            robotRoomSourceIndex: chain.robotRoomSourceIndex,
            robotFlags: chain.robotFlags,
            combat: chain.combat
        )
        assertValidationError(
            .invalidDependency("Training RASBot4 death chain"),
            level.addingTrainingRASBot4DeathChain(wrongHandle)
        )
    }

    func testSchemaElevenRequiresExactLastBot1DeathProducer() throws {
        let level = makeTrainingLastBot1DeathLevel()
        try level.validate()
        XCTAssertEqual(level.schemaVersion, 11)

        let chain = try XCTUnwrap(level.trainingLastBot1DeathChain)
        XCTAssertEqual(chain.robotObjectHandle, 4_127)
        XCTAssertEqual(chain.robotRoomSourceIndex, 14)
        XCTAssertEqual(chain.robotFlags, 5_121)
        XCTAssertEqual(chain.combat, .stockTraining)

        let wrongHandle = TrainingLastBot1DeathChain(
            robotObjectHandle: 2_080,
            robotRoomSourceIndex: chain.robotRoomSourceIndex,
            robotFlags: chain.robotFlags,
            combat: chain.combat
        )
        assertValidationError(
            .invalidDependency("Training LastBot1 death chain"),
            level.addingTrainingLastBot1DeathChain(wrongHandle)
        )

        let robotIndex = try XCTUnwrap(level.objects.firstIndex {
            $0.handle == chain.robotObjectHandle
        })
        let robot = level.objects[robotIndex]
        func replacingRobot(
            instanceName: String = "LastBot1",
            flags: UInt32 = 5_121,
            location: SpatialLocation = .room(14)
        ) -> PlacedObject {
            PlacedObject(
                handle: robot.handle,
                type: robot.type,
                storedID: robot.storedID,
                definition: robot.definition,
                instanceName: instanceName,
                flags: flags,
                doorShields: robot.doorShields,
                location: location,
                position: robot.position,
                orientation: robot.orientation,
                containsType: robot.containsType,
                containsID: robot.containsID,
                containsCount: robot.containsCount,
                lifeLeft: robot.lifeLeft,
                soundSource: robot.soundSource,
                inertScriptName: robot.inertScriptName,
                inertModuleName: robot.inertModuleName,
                lightmapSubmodels: robot.lightmapSubmodels
            )
        }
        for replacement in [
            replacingRobot(instanceName: "LastBot2"),
            replacingRobot(flags: 5_120),
            replacingRobot(location: .room(45)),
        ] {
            var objects = level.objects
            objects[robotIndex] = replacement
            assertValidationError(
                .invalidDependency("Training LastBot1 death chain"),
                replacing(level, objects: objects)
            )
        }

        let presentationIndex = try XCTUnwrap(
            level.objectPresentations.firstIndex {
                $0.objectHandle == chain.robotObjectHandle
            }
        )
        let presentation = level.objectPresentations[presentationIndex]
        var hiddenPresentations = level.objectPresentations
        hiddenPresentations[presentationIndex] = .init(
            objectHandle: presentation.objectHandle,
            primaryModel: presentation.primaryModel,
            mediumModel: presentation.mediumModel,
            lowModel: presentation.lowModel,
            dyingModel: presentation.dyingModel,
            mediumDistance: presentation.mediumDistance,
            lowDistance: presentation.lowDistance,
            isVisible: false
        )
        assertValidationError(
            .invalidDependency("Training LastBot1 death chain"),
            replacing(
                level,
                objectPresentations: hiddenPresentations
            )
        )
    }

    func testSchemaElevenRequiresExactLastBot2DeathProducer() throws {
        let level = makeTrainingLastBot2DeathLevel()
        try level.validate()
        XCTAssertEqual(level.schemaVersion, 11)

        let chain = try XCTUnwrap(level.trainingLastBot2DeathChain)
        XCTAssertEqual(chain.robotObjectHandle, 2_080)
        XCTAssertEqual(chain.robotRoomSourceIndex, 46)
        XCTAssertEqual(chain.robotFlags, 5_121)
        XCTAssertEqual(chain.combat, .stockTraining)

        let wrongHandle = TrainingLastBot2DeathChain(
            robotObjectHandle: 2_081,
            robotRoomSourceIndex: chain.robotRoomSourceIndex,
            robotFlags: chain.robotFlags,
            combat: chain.combat
        )
        assertValidationError(
            .invalidDependency("Training LastBot2 death chain"),
            level.addingTrainingLastBot2DeathChain(wrongHandle)
        )

        let robotIndex = try XCTUnwrap(level.objects.firstIndex {
            $0.handle == chain.robotObjectHandle
        })
        let robot = level.objects[robotIndex]
        func replacingRobot(
            instanceName: String = "LastBot2",
            flags: UInt32 = 5_121,
            location: SpatialLocation = .room(46)
        ) -> PlacedObject {
            PlacedObject(
                handle: robot.handle,
                type: robot.type,
                storedID: robot.storedID,
                definition: robot.definition,
                instanceName: instanceName,
                flags: flags,
                doorShields: robot.doorShields,
                location: location,
                position: robot.position,
                orientation: robot.orientation,
                containsType: robot.containsType,
                containsID: robot.containsID,
                containsCount: robot.containsCount,
                lifeLeft: robot.lifeLeft,
                soundSource: robot.soundSource,
                inertScriptName: robot.inertScriptName,
                inertModuleName: robot.inertModuleName,
                lightmapSubmodels: robot.lightmapSubmodels
            )
        }
        for replacement in [
            replacingRobot(instanceName: "LastBot3"),
            replacingRobot(flags: 5_120),
            replacingRobot(location: .room(45)),
        ] {
            var objects = level.objects
            objects[robotIndex] = replacement
            assertValidationError(
                .invalidDependency("Training LastBot2 death chain"),
                replacing(level, objects: objects)
            )
        }

        let presentationIndex = try XCTUnwrap(
            level.objectPresentations.firstIndex {
                $0.objectHandle == chain.robotObjectHandle
            }
        )
        let presentation = level.objectPresentations[presentationIndex]
        var hiddenPresentations = level.objectPresentations
        hiddenPresentations[presentationIndex] = .init(
            objectHandle: presentation.objectHandle,
            primaryModel: presentation.primaryModel,
            mediumModel: presentation.mediumModel,
            lowModel: presentation.lowModel,
            dyingModel: presentation.dyingModel,
            mediumDistance: presentation.mediumDistance,
            lowDistance: presentation.lowDistance,
            isVisible: false
        )
        assertValidationError(
            .invalidDependency("Training LastBot2 death chain"),
            replacing(
                level,
                objectPresentations: hiddenPresentations
            )
        )
    }

    func testSchemaElevenRequiresExactLastBot3DeathProducer() throws {
        let level = makeTrainingLastBot3DeathLevel()
        try level.validate()
        XCTAssertEqual(level.schemaVersion, 11)

        let chain = try XCTUnwrap(level.trainingLastBot3DeathChain)
        XCTAssertEqual(chain.robotObjectHandle, 2_081)
        XCTAssertEqual(chain.robotRoomSourceIndex, 47)
        XCTAssertEqual(chain.robotFlags, 5_121)
        XCTAssertEqual(chain.combat, .stockTraining)

        let wrongHandle = TrainingLastBot3DeathChain(
            robotObjectHandle: 2_082,
            robotRoomSourceIndex: chain.robotRoomSourceIndex,
            robotFlags: chain.robotFlags,
            combat: chain.combat
        )
        assertValidationError(
            .invalidDependency("Training LastBot3 death chain"),
            level.addingTrainingLastBot3DeathChain(wrongHandle)
        )

        let robotIndex = try XCTUnwrap(level.objects.firstIndex {
            $0.handle == chain.robotObjectHandle
        })
        let robot = level.objects[robotIndex]
        let wrongName = PlacedObject(
            handle: robot.handle,
            type: robot.type,
            storedID: robot.storedID,
            definition: robot.definition,
            instanceName: "LastBot4",
            flags: robot.flags,
            doorShields: robot.doorShields,
            location: robot.location,
            position: robot.position,
            orientation: robot.orientation,
            containsType: robot.containsType,
            containsID: robot.containsID,
            containsCount: robot.containsCount,
            lifeLeft: robot.lifeLeft,
            soundSource: robot.soundSource,
            inertScriptName: robot.inertScriptName,
            inertModuleName: robot.inertModuleName,
            lightmapSubmodels: robot.lightmapSubmodels
        )
        var wrongObjects = level.objects
        wrongObjects[robotIndex] = wrongName
        assertValidationError(
            .invalidDependency("Training LastBot3 death chain"),
            replacing(level, objects: wrongObjects)
        )
    }

    func testSchemaElevenRequiresExactLastBot4DeathProducer() throws {
        let level = makeTrainingLastBot4DeathLevel()
        try level.validate()
        XCTAssertEqual(level.schemaVersion, 11)

        let chain = try XCTUnwrap(level.trainingLastBot4DeathChain)
        XCTAssertEqual(chain.robotObjectHandle, 2_082)
        XCTAssertEqual(chain.robotRoomSourceIndex, 47)
        XCTAssertEqual(chain.robotFlags, 5_121)
        XCTAssertEqual(chain.combat, .stockTraining)

        let wrongHandle = TrainingLastBot4DeathChain(
            robotObjectHandle: 2_083,
            robotRoomSourceIndex: chain.robotRoomSourceIndex,
            robotFlags: chain.robotFlags,
            combat: chain.combat
        )
        assertValidationError(
            .invalidDependency("Training LastBot4 death chain"),
            level.addingTrainingLastBot4DeathChain(wrongHandle)
        )

        let robotIndex = try XCTUnwrap(level.objects.firstIndex {
            $0.handle == chain.robotObjectHandle
        })
        let robot = level.objects[robotIndex]
        let wrongName = PlacedObject(
            handle: robot.handle,
            type: robot.type,
            storedID: robot.storedID,
            definition: robot.definition,
            instanceName: "LastBot5",
            flags: robot.flags,
            doorShields: robot.doorShields,
            location: robot.location,
            position: robot.position,
            orientation: robot.orientation,
            containsType: robot.containsType,
            containsID: robot.containsID,
            containsCount: robot.containsCount,
            lifeLeft: robot.lifeLeft,
            soundSource: robot.soundSource,
            inertScriptName: robot.inertScriptName,
            inertModuleName: robot.inertModuleName,
            lightmapSubmodels: robot.lightmapSubmodels
        )
        var wrongObjects = level.objects
        wrongObjects[robotIndex] = wrongName
        assertValidationError(
            .invalidDependency("Training LastBot4 death chain"),
            replacing(level, objects: wrongObjects)
        )
    }

    func testSchemaElevenRequiresExactLastBot5DeathProducer() throws {
        let level = makeTrainingLastBot5DeathLevel()
        try level.validate()
        XCTAssertEqual(level.schemaVersion, 11)

        let chain = try XCTUnwrap(level.trainingLastBot5DeathChain)
        XCTAssertEqual(chain.robotObjectHandle, 2_083)
        XCTAssertEqual(chain.robotRoomSourceIndex, 48)
        XCTAssertEqual(chain.robotFlags, 5_121)
        XCTAssertEqual(chain.combat, .stockTraining)

        let wrongHandle = TrainingLastBot5DeathChain(
            robotObjectHandle: 2_082,
            robotRoomSourceIndex: chain.robotRoomSourceIndex,
            robotFlags: chain.robotFlags,
            combat: chain.combat
        )
        assertValidationError(
            .invalidDependency("Training LastBot5 death chain"),
            level.addingTrainingLastBot5DeathChain(wrongHandle)
        )

        let robotIndex = try XCTUnwrap(level.objects.firstIndex {
            $0.handle == chain.robotObjectHandle
        })
        let robot = level.objects[robotIndex]
        let wrongName = PlacedObject(
            handle: robot.handle,
            type: robot.type,
            storedID: robot.storedID,
            definition: robot.definition,
            instanceName: "LastBot4",
            flags: robot.flags,
            doorShields: robot.doorShields,
            location: robot.location,
            position: robot.position,
            orientation: robot.orientation,
            containsType: robot.containsType,
            containsID: robot.containsID,
            containsCount: robot.containsCount,
            lifeLeft: robot.lifeLeft,
            soundSource: robot.soundSource,
            inertScriptName: robot.inertScriptName,
            inertModuleName: robot.inertModuleName,
            lightmapSubmodels: robot.lightmapSubmodels
        )
        var wrongObjects = level.objects
        wrongObjects[robotIndex] = wrongName
        assertValidationError(
            .invalidDependency("Training LastBot5 death chain"),
            replacing(level, objects: wrongObjects)
        )
    }

    func testSchemaElevenRequiresExactFinalBotsCompletionChain() throws {
        let level = makeTrainingFinalBotsCompletionLevel()
        try level.validate()

        XCTAssertEqual(level.schemaVersion, 11)
        let chain = try XCTUnwrap(
            level.trainingFinalBotsCompletionChain
        )
        XCTAssertEqual(chain.barrierRoomSourceIndex, 16)
        XCTAssertEqual(chain.orderedPortalIndices, [0, 1])
        XCTAssertEqual(chain.markerLightObjectHandle, 4_118)
        XCTAssertEqual(chain.openMarkerLightDistance, 50)
        XCTAssertEqual(chain.timerDuration, 2)
        XCTAssertEqual(
            chain.completionMessage,
            "Great Job! Now fly through the opened doorway to end your training. Good job Recruit!"
        )
        XCTAssertEqual(chain.completionVoiceSourceName, "done.osf")

        let stockVoice = CanonicalVoiceClip(
            sourceName: "done.osf",
            sourceEntryIndex: 2,
            sampleRate: 22_050,
            channelCount: 1,
            frameCount: 234_609,
            pcm16LittleEndian: Data(),
            pcmSHA256:
                "87efaee428868cf09d74ae72ded48f91ce6f9db55ee823c82fcbf37c07487953",
            sourceArchive: "missions/training.mn3",
            sourceSHA256:
                "a14ce32c2b72fb222c9dfdfdbc277b062ebbb6774e5757c4fe1602b87630383c"
        )
        XCTAssertNoThrow(
            try validateStockTrainingFinalBotsCompletionPackage(
                chain: chain,
                done: stockVoice,
                level: level
            )
        )
        let wrongVoice = CanonicalVoiceClip(
            sourceName: stockVoice.sourceName,
            sourceEntryIndex: 3,
            sampleRate: stockVoice.sampleRate,
            channelCount: stockVoice.channelCount,
            frameCount: stockVoice.frameCount,
            pcm16LittleEndian: stockVoice.pcm16LittleEndian,
            pcmSHA256: stockVoice.pcmSHA256,
            sourceArchive: stockVoice.sourceArchive,
            sourceSHA256: stockVoice.sourceSHA256
        )
        XCTAssertThrowsError(
            try validateStockTrainingFinalBotsCompletionPackage(
                chain: chain,
                done: wrongVoice,
                level: level
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency(
                    "Training Scripts 035/056 completion"
                )
            )
        }

        var hostile = level
        hostile.objects.removeAll {
            $0.handle == chain.markerLightObjectHandle
        }
        assertValidationError(
            .invalidDependency("Training Scripts 035/056 completion"),
            hostile
        )
    }

    func testSchemaElevenRequiresExactScript057FinalGoalChain() throws {
        let level = makeTrainingFinalGoalLevel()
        try level.validate()

        XCTAssertEqual(level.schemaVersion, 11)
        let chain = try XCTUnwrap(level.trainingFinalGoalChain)
        XCTAssertEqual(chain.goalObjectHandle, 6_180)
        XCTAssertEqual(chain.goalRoomSourceIndex, 17)
        XCTAssertEqual(chain.goalObjectFlags, 4_096)
        XCTAssertEqual(
            chain.goalCollisionRadius,
            Float(bitPattern: 0x40a0_84bf)
        )
        let presentation = try XCTUnwrap(
            level.objectPresentations.first {
                $0.objectHandle == chain.goalObjectHandle
            }
        )
        XCTAssertEqual(
            presentation.primaryModel.sourceName,
            "invisiblepowerup.OOF"
        )
        XCTAssertFalse(presentation.isVisible)

        let wrongRadius = TrainingFinalGoalChain(
            goalObjectHandle: chain.goalObjectHandle,
            goalRoomSourceIndex: chain.goalRoomSourceIndex,
            goalObjectFlags: chain.goalObjectFlags,
            goalCollisionRadius: 1
        )
        assertValidationError(
            .invalidDependency("Training Script 057 FinalGoal chain"),
            level.addingTrainingFinalGoalChain(wrongRadius)
        )

        var visiblePresentations = level.objectPresentations
        let presentationIndex = try XCTUnwrap(
            visiblePresentations.firstIndex {
                $0.objectHandle == chain.goalObjectHandle
            }
        )
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
            .invalidDependency("Training Script 057 FinalGoal chain"),
            replacing(level, objectPresentations: visiblePresentations)
        )
    }

    func testSchemaEightRejectsWrongTrainingGalleryMarkerIdentity() throws {
        let level = makeTrainingGalleryBarrierLevel()
        try level.validate()
        let markerIndex = try XCTUnwrap(level.objects.firstIndex {
            $0.handle == 6_163
        })
        let marker = level.objects[markerIndex]

        func replacingMarker(
            type: UInt8,
            instanceName: String
        ) -> PlacedObject {
            PlacedObject(
                handle: marker.handle,
                type: type,
                storedID: marker.storedID,
                definition: marker.definition,
                instanceName: instanceName,
                flags: marker.flags,
                doorShields: marker.doorShields,
                location: marker.location,
                position: marker.position,
                orientation: marker.orientation,
                containsType: marker.containsType,
                containsID: marker.containsID,
                containsCount: marker.containsCount,
                lifeLeft: marker.lifeLeft,
                soundSource: marker.soundSource,
                inertScriptName: marker.inertScriptName,
                inertModuleName: marker.inertModuleName,
                lightmapSubmodels: marker.lightmapSubmodels
            )
        }

        var wrongTypeObjects = level.objects
        wrongTypeObjects[markerIndex] = replacingMarker(
            type: 7,
            instanceName: "FlashLight-2"
        )
        assertValidationError(
            .invalidDependency("Training gallery barrier"),
            replacing(level, objects: wrongTypeObjects)
        )

        var wrongNameObjects = level.objects
        wrongNameObjects[markerIndex] = replacingMarker(
            type: 11,
            instanceName: "Not-FlashLight-2"
        )
        assertValidationError(
            .invalidDependency("Training gallery barrier"),
            replacing(level, objects: wrongNameObjects)
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

    func testSchemaEightRejectsWrongReciprocalGallerySurface() throws {
        let level = makeTrainingGalleryBarrierLevel()
        try level.validate()
        let barrier = level.trainingGalleryBarrier!
        let barrierRoom = level.rooms.first {
            $0.sourceIndex == barrier.barrierRoomSourceIndex
        }!
        let primaryPortal = barrierRoom.portals[
            barrier.orderedPortalIndices[0]
        ]
        let primaryTexture =
            barrierRoom.faces[primaryPortal.faceIndex].texture
        let alternateMaterial = try XCTUnwrap(
            level.presentationMaterials.first {
                $0.texture != primaryTexture && $0.waterProcedural == nil
            }
        )
        let reciprocalRoomIndex = try XCTUnwrap(
            level.rooms.firstIndex {
                $0.sourceIndex == primaryPortal.connectedRoom
            }
        )
        let reciprocalPortal = level.rooms[reciprocalRoomIndex]
            .portals[primaryPortal.connectedPortal]
        let reciprocalFaceIndex = reciprocalPortal.faceIndex
        let reciprocalFace =
            level.rooms[reciprocalRoomIndex].faces[reciprocalFaceIndex]
        var rooms = level.rooms
        rooms[reciprocalRoomIndex].faces[reciprocalFaceIndex] = .init(
            corners: reciprocalFace.corners,
            flags: reciprocalFace.flags,
            portalIndex: reciprocalFace.portalIndex,
            texture: alternateMaterial.texture,
            lightmapInfoIndex: reciprocalFace.lightmapInfoIndex,
            allowsLightCorona: reciprocalFace.allowsLightCorona,
            lightMultiple: reciprocalFace.lightMultiple,
            special: reciprocalFace.special
        )

        assertValidationError(
            .invalidDependency("Training gallery barrier"),
            replacing(
                level,
                rooms: rooms,
                surfacePhysics: level.surfacePhysics
            )
        )

        let forceFieldAlternatePhysics = level.surfacePhysics.map {
            $0.texture == alternateMaterial.texture
                ? SurfacePhysicsEntry(
                    texture: $0.texture,
                    behavior: .forceField
                )
                : $0
        }
        assertValidationError(
            .invalidDependency("Training gallery barrier"),
            replacing(
                level,
                rooms: rooms,
                surfacePhysics: forceFieldAlternatePhysics
            )
        )
    }
}
