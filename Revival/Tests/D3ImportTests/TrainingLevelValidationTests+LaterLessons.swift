import XCTest

extension CanonicalLevelTests {
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
    func testStockTrainingPackageRejectsHostileOpeningVoiceMutations() throws {
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
        let level = stockBase.addingAudioClips(voiceClips: clips)
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
