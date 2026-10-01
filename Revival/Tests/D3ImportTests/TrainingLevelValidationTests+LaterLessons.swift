import XCTest

extension CanonicalLevelTests {
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
            guidebotObjectHandle: 6_164,
            deployedGuidebotObjectType: 2,
            deployedGuidebotMessage:
                "Have the Guidebot help you complete a goal.  Press F4 and select item 1.  Fly over the object he leads you to.",
            deployedGuidebotVoiceSourceName: "guidebotb.osf",
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
