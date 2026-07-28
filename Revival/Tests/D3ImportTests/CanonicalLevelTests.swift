import XCTest

final class CanonicalLevelTests: XCTestCase {
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

    func testRadiusAwareIndoorTraceStopsAtRenderedPortalAndCrossesOpenPortal() throws {
        let rendered = makeIndoorTraceLevel(portalFlags: 0x0000_0001)
        let start = Vector3(x: 0, y: 0, z: 0)
        let end = Vector3(x: 1.75, y: 0, z: 0)

        let blocked = traceIndoorMovement(
            in: rendered,
            startRoom: 10,
            start: start,
            end: end,
            radius: 0.25
        )
        XCTAssertEqual(
            blocked.outcome,
            .wallHit(
                .init(
                    roomSourceIndex: 10,
                    faceIndex: 0,
                    contactPoint: .init(x: 1, y: 0, z: 0),
                    normal: .init(x: -1, y: 0, z: 0),
                    distance: 0.75
                )
            )
        )
        XCTAssertEqual(blocked.finalPosition, .init(x: 0.75, y: 0, z: 0))
        XCTAssertEqual(blocked.containingRoomSourceIndex, 10)
        XCTAssertEqual(blocked.visitedRoomSourceIndices, [10])

        let open = traceIndoorMovement(
            in: makeIndoorTraceLevel(portalFlags: 0),
            startRoom: 10,
            start: start,
            end: end,
            radius: 0.25
        )
        XCTAssertEqual(open.outcome, .noHit)
        XCTAssertEqual(open.finalPosition, end)
        XCTAssertEqual(open.containingRoomSourceIndex, 20)
        XCTAssertEqual(open.visitedRoomSourceIndices, [10, 20])

        for portalFlags: UInt32 in [0x0000_0003, 0x0000_0004] {
            let passable = traceIndoorMovement(
                in: makeIndoorTraceLevel(portalFlags: portalFlags),
                startRoom: 10,
                start: start,
                end: end,
                radius: 0.25
            )
            XCTAssertEqual(passable.outcome, .noHit)
            XCTAssertEqual(passable.containingRoomSourceIndex, 20)
        }
    }

    func testRenderedPortalUsesTypedFlythroughSurfacePhysics() {
        let rendered = makeIndoorTraceLevel(portalFlags: 0x0000_0001)
        let texture = rendered.rooms[0].faces[0].texture
        let flythrough = rendered.addingSurfacePhysics([
            .init(texture: texture, behavior: .passThrough),
        ])

        let trace = traceIndoorMovement(
            in: flythrough,
            startRoom: 10,
            start: .init(x: 0, y: 0, z: 0),
            end: .init(x: 1.75, y: 0, z: 0),
            radius: 0.25
        )

        XCTAssertEqual(trace.outcome, .noHit)
        XCTAssertEqual(trace.containingRoomSourceIndex, 20)
        XCTAssertEqual(trace.visitedRoomSourceIndices, [10, 20])
    }

    func testTypedFlythroughSurfaceMakesANonPortalFacePassable() throws {
        let level = makeNonPortalTraceLevel(behavior: .passThrough)
        try level.validate()
        let end = Vector3(x: 1.5, y: 0, z: 0)

        let trace = traceIndoorMovement(
            in: level,
            startRoom: 10,
            start: .init(x: 0, y: 0, z: 0),
            end: end,
            radius: 0.25
        )

        XCTAssertEqual(trace.outcome, .noHit)
        XCTAssertEqual(trace.finalPosition, end)
        XCTAssertEqual(trace.visitedRoomSourceIndices, [10])
    }

    func testRadiusContactOwnershipUsesTheStoppedCenterAcrossVisitedRooms() {
        let level = makeIndoorTraceLevelWithNearWall()

        let trace = traceIndoorMovement(
            in: level,
            startRoom: 10,
            start: .init(x: 0, y: 0, z: 0),
            end: .init(x: 2, y: 0, z: 0),
            radius: 0.25
        )

        guard case .wallHit(let contact) = trace.outcome else {
            return XCTFail("Expected the near wall in source room 20")
        }
        XCTAssertEqual(contact.roomSourceIndex, 20)
        XCTAssertEqual(trace.finalPosition.x, 0.85, accuracy: 0.000_1)
        XCTAssertEqual(trace.visitedRoomSourceIndices, [10, 20])
        XCTAssertEqual(trace.containingRoomSourceIndex, 10)
    }

    func testEarlierSchemasAndIncompleteCanonicalTablesAreRejected() throws {
        let base = removingDefaultPlayerPresentation(
            from: makeMinimalCanonicalPackageLevel()
        )
        assertValidationError(.invalidIdentity, replacing(base, schemaVersion: 2))
        assertValidationError(.invalidIdentity, replacing(base, schemaVersion: 3))
        assertValidationError(.invalidIdentity, replacing(base, schemaVersion: 4))
        assertValidationError(.invalidIdentity, replacing(base, schemaVersion: 5))
        assertValidationError(.invalidIdentity, replacing(base, schemaVersion: 6))
        assertValidationError(
            .invalidSurfacePhysics,
            replacing(base, surfacePhysics: [])
        )

        let modelSource = SourceResource(storedIndex: 0, sourceName: "Synthetic.OOF")
        let missingTexture = SourceResource(storedIndex: 1, sourceName: "model-surface")
        let model = CanonicalModel(
            source: modelSource,
            collisionRadius: 1,
            submodels: [
                .init(
                    sourceIndex: 0,
                    parentIndex: nil,
                    offset: .zero,
                    vertices: [
                        .init(position: .zero, alpha: 1),
                        .init(position: .init(x: 1, y: 0, z: 0), alpha: 1),
                        .init(position: .init(x: 0, y: 1, z: 0), alpha: 1),
                    ],
                    faces: [
                        .init(
                            normal: .init(x: 0, y: 0, z: 1),
                            corners: [
                                .init(vertexIndex: 0, u: 0, v: 0),
                                .init(vertexIndex: 1, u: 1, v: 0),
                                .init(vertexIndex: 2, u: 0, v: 1),
                            ],
                            material: .texture(missingTexture)
                        ),
                    ],
                    presentation: .standard
                ),
            ],
            bounds: .init(minimum: .zero, maximum: .init(x: 1, y: 1, z: 0)),
            sourceArchive: base.source.profileFiles[0].relativePath,
            sourceSHA256: String(repeating: "e", count: 64)
        )
        let player = makePlacedObject(
            handle: 2_048,
            type: D3SourceIdentity.playerObjectType,
            storedID: 0,
            location: .room(3)
        )
        let presentation = ObjectPresentationReference(
            objectHandle: player.handle,
            primaryModel: modelSource,
            mediumModel: nil,
            lowModel: nil,
            dyingModel: nil,
            mediumDistance: nil,
            lowDistance: nil
        )
        let dependency = DependencyRecord(
            category: "model",
            source: modelSource,
            state: "presentation-payload-imported",
            provenance: "synthetic canonical fixture"
        )
        let shipSource = SourceResource(storedIndex: 0, sourceName: "Pyro-GL")
        let ship = CanonicalShipDefinition(
            source: shipSource,
            primaryModel: modelSource,
            presentationSize: 1,
            physics: .init(
                mass: 30,
                drag: 90,
                fullThrust: 5_400,
                behaviors: [.turnroll, .wiggle, .usesThrust],
                rotationalDrag: 225,
                fullRotationalThrust: 6_860_000,
                numberOfBounces: -1,
                initialForwardVelocity: 0,
                initialAngularVelocity: .zero,
                wiggleAmplitude: 0.17,
                wigglesPerSecond: 0.9,
                coefficientOfRestitution: 1,
                hitDieDot: -1,
                maximumTurnrollRate: 8_000,
                turnrollRatio: 0.13
            )
        )
        let binding = DefaultPlayerBinding(
            playerID: 0,
            objectHandle: player.handle,
            ship: shipSource
        )
        let shipDependency = DependencyRecord(
            category: "ship-definition",
            source: shipSource,
            state: "canonical-typed-definition",
            provenance: "synthetic canonical fixture"
        )
        let incomplete = replacing(
            base,
            objects: [player],
            models: [model],
            shipDefinitions: [ship],
            defaultPlayerBinding: binding,
            objectPresentations: [presentation],
            dependencyManifest: .init(
                current: base.dependencyManifest.current + [dependency, shipDependency],
                historicalEagerBaseline: nil
            )
        )

        assertValidationError(
            .invalidDependency("missing texture:model-surface"),
            incomplete
        )

        let modelMaterial = PresentationMaterial(
            texture: missingTexture,
            bitmapSourceName: "model-surface.ogf",
            image: .init(width: 1, height: 1, rgba8: Data([255, 255, 255, 255])),
            blend: .opaque,
            lightmapBlend: .none,
            waterProcedural: nil,
            sourceArchive: base.source.profileFiles[0].relativePath,
            sourceSHA256: String(repeating: "f", count: 64)
        )
        let textureDependency = DependencyRecord(
            category: "texture",
            source: missingTexture,
            state: "presentation-payload-imported",
            provenance: "synthetic canonical fixture"
        )
        let complete = replacing(
            base,
            objects: [player],
            presentationMaterials: base.presentationMaterials + [modelMaterial],
            models: [model],
            shipDefinitions: [ship],
            defaultPlayerBinding: binding,
            objectPresentations: [presentation],
            dependencyManifest: .init(
                current: base.dependencyManifest.current + [
                    dependency,
                    shipDependency,
                    textureDependency,
                ],
                historicalEagerBaseline: nil
            )
        )

        XCTAssertNoThrow(try complete.validate())
        XCTAssertEqual(
            try JSONDecoder().decode(Level.self, from: canonicalJSONData(complete)),
            complete
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

    func testRevivalMobileBackupExclusionIsScopedToReimportableContent() {
        let library = CanonicalPackageLibrary.revivalMobile

        XCTAssertEqual(library.rootURL.lastPathComponent, "Content")
        XCTAssertEqual(
            library.rootURL.deletingLastPathComponent().lastPathComponent,
            "RevivalMobile"
        )
        XCTAssertEqual(library.reimportableContentBackupExclusionURL, library.rootURL)
        XCTAssertNotEqual(
            library.reimportableContentBackupExclusionURL,
            library.rootURL.deletingLastPathComponent()
        )
    }

    func testCanonicalPackageRequestsStartOneAtATimeInFIFOOrder() {
        let first = URL(fileURLWithPath: "/tmp/first.revival")
        let second = URL(fileURLWithPath: "/tmp/second.revival")
        var requests = CanonicalPackageRequestQueue<URL>()

        requests.append(first)
        XCTAssertEqual(requests.startNextIfIdle(), first)

        requests.append(second)
        XCTAssertNil(requests.startNextIfIdle())

        requests.finishCurrent()
        XCTAssertEqual(requests.startNextIfIdle(), second)

        requests.finishCurrent()
        XCTAssertNil(requests.startNextIfIdle())
    }

    func testNativeLibraryStagesValidatesPromotesAndActivatesACanonicalBase() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(path: "candidate.revival", directoryHint: .isDirectory)
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(path: "library", directoryHint: .isDirectory)
        )
        let level = makeMinimalCanonicalPackageLevel()
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try writeCanonicalPackage(level, to: candidate)

        let activation = try library.installAndActivate(from: candidate)

        XCTAssertEqual(activation.level, level)
        XCTAssertEqual(try library.load(activation.reference), level)
        XCTAssertEqual(try library.loadActive(), activation)
        XCTAssertTrue(FileManager.default.fileExists(atPath: candidate.path))
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: activation.installedPackageURL.path)
        )
        XCTAssertEqual(
            activation.installedPackageURL.deletingLastPathComponent(),
            library.rootURL.appending(path: "packages", directoryHint: .isDirectory)
        )
        XCTAssertFalse(
            try FileManager.default.contentsOfDirectory(
                atPath: activation.installedPackageURL.deletingLastPathComponent().path
            ).contains { $0.hasPrefix(".candidate-") }
        )
    }

    func testInvalidNativeInstallPreservesThePriorActiveBaseAndCleansStaging() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let priorCandidate = root.appending(path: "prior.revival", directoryHint: .isDirectory)
        let invalidCandidate = root.appending(path: "invalid.revival", directoryHint: .isDirectory)
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(path: "library", directoryHint: .isDirectory)
        )
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try writeCanonicalPackage(makeMinimalCanonicalPackageLevel(), to: priorCandidate)
        let prior = try library.installAndActivate(from: priorCandidate)
        try FileManager.default.createDirectory(
            at: invalidCandidate,
            withIntermediateDirectories: false
        )
        try Data("not canonical".utf8).write(
            to: invalidCandidate.appending(path: "content.json")
        )

        XCTAssertThrowsError(try library.installAndActivate(from: invalidCandidate))
        XCTAssertEqual(try library.loadActive(), prior)
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(
                atPath: library.rootURL.appending(path: "packages").path
            ),
            [prior.installedPackageURL.lastPathComponent]
        )
    }

    func testUnboundPresentationPackageCannotReplaceTheActiveBase() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let priorCandidate = root.appending(path: "prior.revival", directoryHint: .isDirectory)
        let unboundCandidate = root.appending(
            path: "unbound.revival",
            directoryHint: .isDirectory
        )
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(path: "library", directoryHint: .isDirectory)
        )
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let bound = makeSliceSixObjectRenderLevel()
        try writeCanonicalPackage(bound, to: priorCandidate)
        let prior = try library.installAndActivate(from: priorCandidate)
        try writeCanonicalPackage(bound, to: unboundCandidate)
        try overwriteCanonicalPackageLevel(
            removingDefaultPlayerPresentation(from: makeMinimalCanonicalPackageLevel()),
            at: unboundCandidate
        )

        XCTAssertThrowsError(try library.installAndActivate(from: unboundCandidate))
        XCTAssertEqual(try library.loadActive(), prior)
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(
                atPath: library.rootURL.appending(path: "packages").path
            ),
            [prior.installedPackageURL.lastPathComponent]
        )
    }

    func testDefaultPlayerBindingRequiresAnIndoorRoom() throws {
        let base = makeMinimalCanonicalPackageLevel()
        let binding = try XCTUnwrap(base.defaultPlayerBinding)
        var objects = base.objects
        let playerIndex = try XCTUnwrap(
            objects.firstIndex { $0.handle == binding.objectHandle }
        )
        let player = objects[playerIndex]
        objects[playerIndex] = PlacedObject(
            handle: player.handle,
            type: player.type,
            storedID: player.storedID,
            definition: player.definition,
            instanceName: player.instanceName,
            flags: player.flags,
            doorShields: player.doorShields,
            location: .terrainCell(0),
            position: player.position,
            orientation: player.orientation,
            containsType: player.containsType,
            containsID: player.containsID,
            containsCount: player.containsCount,
            lifeLeft: player.lifeLeft,
            soundSource: player.soundSource,
            inertScriptName: player.inertScriptName,
            inertModuleName: player.inertModuleName,
            lightmapSubmodels: player.lightmapSubmodels
        )

        assertValidationError(
            .invalidDependency("default player ship binding"),
            replacing(base, objects: objects)
        )
    }

    func testNativeCandidateCopyFailurePreservesThePriorActiveBase() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(path: "candidate.revival", directoryHint: .isDirectory)
        let missing = root.appending(path: "missing.revival", directoryHint: .isDirectory)
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(path: "library", directoryHint: .isDirectory)
        )
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try writeCanonicalPackage(makeMinimalCanonicalPackageLevel(), to: candidate)
        let prior = try library.installAndActivate(from: candidate)

        XCTAssertThrowsError(try library.installAndActivate(from: missing))
        XCTAssertEqual(try library.loadActive(), prior)
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(
                atPath: library.rootURL.appending(path: "packages").path
            ),
            [prior.installedPackageURL.lastPathComponent]
        )
    }

    func testNativePromotionFailurePreservesThePriorActiveBaseAndCleansStaging() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let priorCandidate = root.appending(path: "prior.revival", directoryHint: .isDirectory)
        let successorCandidate = root.appending(
            path: "successor.revival",
            directoryHint: .isDirectory
        )
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(path: "library", directoryHint: .isDirectory)
        )
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try writeCanonicalPackage(makeMinimalCanonicalPackageLevel(), to: priorCandidate)
        let prior = try library.installAndActivate(from: priorCandidate)
        try writeCanonicalPackage(
            makeMinimalCanonicalPackageLevel(levelKey: "test.level.successor"),
            to: successorCandidate
        )
        let successorManifest = try JSONDecoder().decode(
            CanonicalPackageManifest.self,
            from: Data(contentsOf: successorCandidate.appending(path: "content.json"))
        )
        let successorIdentity = canonicalSHA256(
            try canonicalJSONData(successorManifest)
        )
        let destination = library.rootURL
            .appending(path: "packages", directoryHint: .isDirectory)
            .appending(path: "\(successorIdentity).revival", directoryHint: .isDirectory)
        let missingTarget = root.appending(path: "missing-promotion-target")
        try FileManager.default.createSymbolicLink(
            at: destination,
            withDestinationURL: missingTarget
        )

        XCTAssertThrowsError(
            try library.installAndActivate(from: successorCandidate)
        )
        XCTAssertEqual(try library.loadActive(), prior)
        XCTAssertEqual(
            try destination.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink,
            true
        )
        XCTAssertFalse(
            try FileManager.default.contentsOfDirectory(
                atPath: library.rootURL.appending(path: "packages").path
            ).contains { $0.hasPrefix(".candidate-") }
        )
    }

    func testNativeLibraryRemovesOnlyItsAbandonedStagingOnNextPreparation() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let library = CanonicalPackageLibrary(rootURL: root)
        let packages = root.appending(path: "packages", directoryHint: .isDirectory)
        let abandoned = packages.appending(
            path: ".candidate-abandoned.revival",
            directoryHint: .isDirectory
        )
        let unrelated = packages.appending(
            path: ".unrelated.revival",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: root) }

        try library.prepareForUse()
        try FileManager.default.createDirectory(at: abandoned, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: unrelated, withIntermediateDirectories: false)

        try library.prepareForUse()

        XCTAssertFalse(FileManager.default.fileExists(atPath: abandoned.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
    }

    func testNativeInstallRequiresAbandonedStagingRecoveryFirst() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(path: "candidate.revival", directoryHint: .isDirectory)
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(path: "library", directoryHint: .isDirectory)
        )
        let abandoned = library.rootURL
            .appending(path: "packages", directoryHint: .isDirectory)
            .appending(path: ".candidate-abandoned.revival", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try writeCanonicalPackage(makeMinimalCanonicalPackageLevel(), to: candidate)
        try library.prepareForUse()
        try FileManager.default.createDirectory(at: abandoned, withIntermediateDirectories: false)

        XCTAssertThrowsError(try library.installAndActivate(from: candidate)) { error in
            XCTAssertEqual(error as? CanonicalPackageError, .abandonedStagingRequiresRecovery)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: abandoned.path))
        XCTAssertNil(try library.loadActive())
    }

    func testNativeLibraryRejectsADuplicateIdentityWithoutChangingTheActiveBase() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let firstCandidate = root.appending(path: "first.revival", directoryHint: .isDirectory)
        let secondCandidate = root.appending(path: "second.revival", directoryHint: .isDirectory)
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(path: "library", directoryHint: .isDirectory)
        )
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try writeCanonicalPackage(makeMinimalCanonicalPackageLevel(), to: firstCandidate)
        try writeCanonicalPackage(
            makeMinimalCanonicalPackageLevel(levelKey: "test.level.successor"),
            to: secondCandidate
        )
        let duplicate = try library.installAndActivate(from: firstCandidate)
        let active = try library.installAndActivate(from: secondCandidate)
        let manifestURL = firstCandidate.appending(path: "content.json")
        let manifestObject = try JSONSerialization.jsonObject(
            with: Data(contentsOf: manifestURL)
        )
        try JSONSerialization.data(
            withJSONObject: manifestObject,
            options: [.prettyPrinted]
        ).write(to: manifestURL)

        XCTAssertThrowsError(try library.installAndActivate(from: firstCandidate)) { error in
            XCTAssertEqual(
                error as? CanonicalPackageError,
                .duplicatePackageIdentity(duplicate.reference.identitySHA256)
            )
        }
        XCTAssertEqual(try library.loadActive(), active)
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(
                atPath: library.rootURL.appending(path: "packages").path
            ).count,
            2
        )
    }

    func testNativeLibraryResolvesAnInstalledMatchingBaseWithoutReactivatingIt() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let firstCandidate = root.appending(path: "first.revival", directoryHint: .isDirectory)
        let secondCandidate = root.appending(path: "second.revival", directoryHint: .isDirectory)
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(path: "library", directoryHint: .isDirectory)
        )
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try writeCanonicalPackage(makeMinimalCanonicalPackageLevel(), to: firstCandidate)
        try writeCanonicalPackage(
            makeMinimalCanonicalPackageLevel(levelKey: "test.level.successor"),
            to: secondCandidate
        )
        let first = try library.installAndActivate(from: firstCandidate)
        let active = try library.installAndActivate(from: secondCandidate)

        let resolved = try library.loadInstalledPackage(matching: firstCandidate)

        XCTAssertEqual(resolved, first)
        XCTAssertEqual(try library.loadActive(), active)
    }

    func testSchemaTwoWriterRejectsTopologyWithoutUsablePresentation() {
        let topologyOnly = makeMinimalCanonicalLevel()
        let package = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: package) }

        XCTAssertThrowsError(try writeCanonicalPackage(topologyOnly, to: package)) { error in
            XCTAssertEqual(
                error as? LevelValidationError,
                .invalidDependency("missing canonical presentation")
            )
        }
    }

    func testSchemaTwoLoaderRejectsAHostileTopologyOnlyPackage() throws {
        let valid = makeMinimalCanonicalPackageLevel()
        let topologyOnly = makeMinimalCanonicalLevel()
        let package = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: package) }

        try writeCanonicalPackage(valid, to: package)
        let levelURL = package.appending(
            path: "levels/\(valid.levelKey)/level.json"
        )
        let topologyData = try canonicalJSONData(topologyOnly)
        try topologyData.write(to: levelURL)

        let manifestURL = package.appending(path: "content.json")
        let manifest = try JSONDecoder().decode(
            CanonicalPackageManifest.self,
            from: Data(contentsOf: manifestURL)
        )
        let hostileManifest = CanonicalPackageManifest(
            packageSchemaVersion: manifest.packageSchemaVersion,
            importerContractVersion: manifest.importerContractVersion,
            profileIdentifier: topologyOnly.source.profileIdentifier,
            acceptedSourceFiles: topologyOnly.source.profileFiles,
            campaigns: [
                .init(
                    missionKey: topologyOnly.missionKey,
                    completeLevelKeys: [topologyOnly.levelKey]
                ),
            ],
            levels: [
                .init(
                    levelKey: topologyOnly.levelKey,
                    relativePath: "levels/\(topologyOnly.levelKey)/level.json",
                    sha256: canonicalSHA256(topologyData)
                ),
            ],
            translatedFeatureCoverage: manifest.translatedFeatureCoverage,
            deferredFeatureCoverage: manifest.deferredFeatureCoverage,
            source: topologyOnly.source,
            sourceEntries: topologyOnly.sourceChunks,
            currentDependencies: topologyOnly.dependencyManifest.current,
            rights: manifest.rights
        )
        try canonicalJSONData(hostileManifest).write(to: manifestURL)

        XCTAssertThrowsError(try loadCanonicalLevel(from: package)) { error in
            XCTAssertEqual(error as? CanonicalPackageError, .identityMismatch)
        }
    }

    func testValidatesSparseRoomsAndReciprocalPortalsWithoutCompactingIdentity() throws {
        let level = makeMinimalCanonicalLevel()

        XCTAssertNoThrow(try level.validate())
        XCTAssertEqual(level.rooms.map(\.sourceIndex), [2, 4])
    }

    func testWritesDeterministicPackageAndReloadsThroughSharedModel() throws {
        let level = makeMinimalCanonicalPackageLevel()
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let firstPackage = temporaryDirectory.appending(path: "first.revival", directoryHint: .isDirectory)
        let secondPackage = temporaryDirectory.appending(path: "second.revival", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: false)
        try writeCanonicalPackage(level, to: firstPackage)
        try writeCanonicalPackage(level, to: secondPackage)

        let levelPath = "levels/\(level.levelKey)/level.json"
        XCTAssertEqual(
            try Data(contentsOf: firstPackage.appending(path: levelPath)),
            try Data(contentsOf: secondPackage.appending(path: levelPath))
        )
        XCTAssertEqual(
            try Data(contentsOf: firstPackage.appending(path: "content.json")),
            try Data(contentsOf: secondPackage.appending(path: "content.json"))
        )
        XCTAssertEqual(try loadCanonicalLevel(from: firstPackage), level)
    }

    func testSchemaNineLoaderDefaultsAbsentSoundClipsToEmpty() throws {
        let level = makeMinimalCanonicalPackageLevel()
        XCTAssertEqual(level.schemaVersion, 9)
        let package = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: package) }
        try writeCanonicalPackage(level, to: package)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: canonicalJSONData(level)
            ) as? [String: Any]
        )
        object.removeValue(forKey: "soundClips")
        let legacyLevelData = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
        try overwriteCanonicalPackageLevelData(
            legacyLevelData,
            identity: level,
            at: package
        )

        let loaded = try loadCanonicalLevel(from: package)

        XCTAssertEqual(loaded.schemaVersion, 9)
        XCTAssertEqual(loaded.soundClips, [])
    }

    func testCanonicalLoaderRejectsOverflowingPCMMetadata() throws {
        let base = makeMinimalCanonicalPackageLevel()
        let archive = try XCTUnwrap(
            base.source.profileFiles.first?.relativePath
        )
        let voice = CanonicalVoiceClip(
            sourceName: "overflow.osf",
            sourceEntryIndex: 999,
            sampleRate: 22_050,
            channelCount: 1,
            frameCount: Int.max / 2 + 1,
            pcm16LittleEndian: Data([0, 0]),
            pcmSHA256: canonicalSHA256(Data([0, 0])),
            sourceArchive: archive,
            sourceSHA256: String(repeating: "a", count: 64)
        )
        let hostile = replacing(
            base,
            voiceClips: [voice],
            dependencyManifest: .init(
                current: base.dependencyManifest.current + [
                    .init(
                        category: "voice",
                        source: .init(
                            storedIndex: voice.sourceEntryIndex,
                            sourceName: voice.sourceName
                        ),
                        state: "canonical-pcm-imported",
                        provenance: "overflow fixture"
                    ),
                ],
                historicalEagerBaseline:
                    base.dependencyManifest.historicalEagerBaseline
            )
        )
        let package = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: package) }
        try writeCanonicalPackage(base, to: package)
        try overwriteCanonicalPackageLevel(hostile, at: package)

        XCTAssertThrowsError(try loadCanonicalLevel(from: package)) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Canonical voice clip")
            )
        }
    }

    func testContentManifestCarriesTheCanonicalContractProvenanceCoverageAndRights() throws {
        let base = makeMinimalCanonicalPackageLevel()
        let source = LevelSource(
            profileIdentifier: base.source.profileIdentifier,
            profileFiles: base.source.profileFiles,
            archiveSHA256: base.source.archiveSHA256,
            levelSHA256: base.source.levelSHA256,
            d3lvVersion: base.source.d3lvVersion,
            archiveEntryName: "training.d3l",
            archiveEntryOffset: 32,
            archiveEntryByteCount: 64,
            referenceChecksum: String(repeating: "c", count: 32),
            referenceChecksumBasis: "pinned-source-provenance-implied-by-exact-level-sha256"
        )
        let dependency = DependencyRecord(
            category: "texture",
            source: .init(storedIndex: 0, sourceName: "wall"),
            state: "presentation-payload-imported",
            provenance: "TXNM"
        )
        let chunk = SourceChunkRecord(
            name: "ROOM",
            byteCount: 1,
            sha256: String(repeating: "a", count: 64),
            disposition: "canonical-topology"
        )
        let dependencies = base.dependencyManifest.current.map {
            $0.category == dependency.category && $0.source == dependency.source
                ? dependency
                : $0
        }
        let level = replacing(
            base,
            source: source,
            dependencyManifest: .init(current: dependencies, historicalEagerBaseline: nil),
            sourceChunks: [chunk]
        )
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let package = temporaryDirectory.appending(path: "content.revival", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: false)
        try writeCanonicalPackage(level, to: package)
        let manifest = try JSONDecoder().decode(
            CanonicalPackageManifest.self,
            from: Data(contentsOf: package.appending(path: "content.json"))
        )

        XCTAssertEqual(manifest.packageSchemaVersion, 2)
        XCTAssertEqual(manifest.importerContractVersion, 1)
        XCTAssertEqual(manifest.profileIdentifier, source.profileIdentifier)
        XCTAssertEqual(manifest.acceptedSourceFiles, source.profileFiles)
        XCTAssertEqual(manifest.campaigns, [
            .init(missionKey: level.missionKey, completeLevelKeys: [level.levelKey]),
        ])
        XCTAssertEqual(manifest.levels.map(\.levelKey), [level.levelKey])
        XCTAssertEqual(
            manifest.levels.map(\.relativePath),
            ["levels/\(level.levelKey)/level.json"]
        )
        XCTAssertEqual(
            manifest.translatedFeatureCoverage,
            ["complete-level-topology", "fixed-camera-portal-presentation"]
        )
        XCTAssertEqual(Set(manifest.deferredFeatureCoverage), [
            "behavior-execution",
            "matcen-production",
            "volumetric-navigation-rebuild",
        ])
        XCTAssertEqual(manifest.source, source)
        XCTAssertEqual(manifest.sourceEntries, [chunk])
        XCTAssertEqual(manifest.currentDependencies, dependencies)
        XCTAssertEqual(manifest.rights.classification, "user-owned-retail")
        XCTAssertTrue(manifest.rights.localOnly)
        XCTAssertFalse(manifest.rights.redistributionAllowed)
    }

    func testLoaderRejectsARegularFileReplacedByASymbolicLink() throws {
        let level = makeMinimalCanonicalPackageLevel()
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let package = temporaryDirectory.appending(path: "content.revival", directoryHint: .isDirectory)
        let outside = temporaryDirectory.appending(path: "outside.json")
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: false)
        try writeCanonicalPackage(level, to: package)
        let levelURL = package.appending(path: "levels/\(level.levelKey)/level.json")
        let original = try Data(contentsOf: levelURL)
        try original.write(to: outside)
        try FileManager.default.removeItem(at: levelURL)
        try FileManager.default.createSymbolicLink(at: levelURL, withDestinationURL: outside)

        XCTAssertThrowsError(try loadCanonicalLevel(from: package)) { error in
            XCTAssertEqual(error as? CanonicalPackageError, .notRegularFile("level.json"))
        }
    }

    func testCanonicalLoaderRejectsInvalidPlayerIDs() throws {
        let base = makeMinimalCanonicalPackageLevel()
        let firstPlayer = base.objects.first {
            $0.handle == base.defaultPlayerBinding?.objectHandle
        }!
        let secondPlayer = makePlacedObject(handle: 2_049, type: 4, storedID: 2)
        let validLevel = replacing(
            base,
            objects: [firstPlayer, secondPlayer]
        )
        let cases: [([PlacedObject], LevelValidationError)] = [
            (
                [firstPlayer, makePlacedObject(handle: 2_049, type: 4, storedID: 32)],
                .invalidPlayerID(handle: 2_049, playerID: 32)
            ),
            (
                [firstPlayer, makePlacedObject(handle: 2_049, type: 4, storedID: 0)],
                .duplicatePlayerID(handle: 2_049, playerID: 0)
            ),
        ]

        for (objects, expectedError) in cases {
            let temporaryDirectory = FileManager.default.temporaryDirectory
                .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            let package = temporaryDirectory
                .appending(path: "content.revival", directoryHint: .isDirectory)
            defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

            try FileManager.default.createDirectory(
                at: temporaryDirectory,
                withIntermediateDirectories: false
            )
            try writeCanonicalPackage(validLevel, to: package)
            try overwriteCanonicalPackageLevel(
                replacing(validLevel, objects: objects),
                at: package
            )

            XCTAssertThrowsError(try loadCanonicalLevel(from: package)) { error in
                XCTAssertEqual(error as? LevelValidationError, expectedError)
            }
        }
    }

    func testCanonicalLoaderRejectsDegenerateRoomGeometryAtThePackageBoundary() throws {
        let valid = makeMinimalCanonicalPackageLevel()
        let roomIndex = try XCTUnwrap(valid.rooms.firstIndex { $0.sourceIndex == 3 })
        let room = valid.rooms[roomIndex]
        let hostileRoom = replacing(
            room,
            vertices: [Vector3](repeating: room.vertices[0], count: room.vertices.count)
        )
        var hostileRooms = valid.rooms
        hostileRooms[roomIndex] = hostileRoom
        let hostile = replacing(valid, rooms: hostileRooms)
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let package = root.appending(path: "hostile.revival", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try writeCanonicalPackage(valid, to: package)
        try overwriteCanonicalPackageLevel(hostile, at: package)

        XCTAssertThrowsError(try loadCanonicalLevel(from: package)) { error in
            XCTAssertEqual(
                error as? LevelValidationError,
                .invalidFace(room: 3, face: 0)
            )
        }
    }

    func testCanonicalLoaderAcceptsOutsideWaterBlobCentersAndPreservesSourceClipping() throws {
        let base = makeMinimalCanonicalPackageLevel()
        let sourceMaterial = base.presentationMaterials[0]
        func waterMaterial(x1: UInt8, y1: UInt8, size: UInt8 = 1) -> PresentationMaterial {
            PresentationMaterial(
                texture: sourceMaterial.texture,
                bitmapSourceName: sourceMaterial.bitmapSourceName,
                image: .init(
                    width: 128,
                    height: 128,
                    rgba8: Data(repeating: 255, count: 128 * 128 * 4)
                ),
                blend: .additiveSourceAlpha(opacity: 178),
                lightmapBlend: .none,
                waterProcedural: .init(
                    evaluationIntervalSeconds: 0,
                    lightingShift: 3,
                    dampingShift: 6,
                    elements: [
                        .init(
                            kind: .heightBlob,
                            frequency: 20,
                            speed: 40,
                            size: size,
                            x1: x1,
                            y1: y1,
                            x2: 0,
                            y2: 0
                        ),
                    ]
                ),
                sourceArchive: sourceMaterial.sourceArchive,
                sourceSHA256: sourceMaterial.sourceSHA256
            )
        }
        let valid = replacing(
            base,
            presentationMaterials: [waterMaterial(x1: 127, y1: 127)]
        )
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let package = root.appending(path: "hostile.revival", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try writeCanonicalPackage(valid, to: package)
        let cases: [(x1: UInt8, y1: UInt8, size: UInt8, writes: Bool)] = [
            (128, 64, 1, false),
            (129, 64, 1, false),
            (64, 128, 1, false),
            (64, 129, 1, false),
            (.max, 64, 1, false),
            (128, 64, 3, true),
        ]
        for (x1, y1, size, writes) in cases {
            let outside = replacing(
                base,
                presentationMaterials: [waterMaterial(x1: x1, y1: y1, size: size)]
            )
            try overwriteCanonicalPackageLevel(outside, at: package)

            let loaded = try loadCanonicalLevel(from: package)
            let material = try XCTUnwrap(loaded.presentationMaterials.first)
            let definition = try XCTUnwrap(material.waterProcedural)
            var evaluator = WaterProceduralEvaluator(
                image: material.image,
                definition: definition
            )
            var noElements = WaterProceduralEvaluator(
                image: material.image,
                definition: .init(
                    evaluationIntervalSeconds: definition.evaluationIntervalSeconds,
                    lightingShift: definition.lightingShift,
                    dampingShift: definition.dampingShift,
                    elements: []
                )
            )

            let evaluated = evaluator.rgba8(visualTick: 0)
            let unchanged = noElements.rgba8(visualTick: 0)
            if writes {
                XCTAssertNotEqual(
                    evaluated,
                    unchanged,
                    "Expected source-clipped overlap for center (\(x1), \(y1)), size \(size)"
                )
            } else {
                XCTAssertEqual(
                    evaluated,
                    unchanged,
                    "Expected source-clipped no-write behavior for center (\(x1), \(y1)), size \(size)"
                )
            }
        }
    }

    func testNativeLibraryAcceptsPreparedButUnscheduledCoronaBeforeActivation() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let priorCandidate = root.appending(path: "prior.revival", directoryHint: .isDirectory)
        let successorCandidate = root.appending(
            path: "successor.revival",
            directoryHint: .isDirectory
        )
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(path: "library", directoryHint: .isDirectory)
        )
        let priorLevel = makeSliceSixObjectRenderLevel()
        let validSuccessor = priorLevel
        let playerView = defaultPlayerView(in: validSuccessor)
        let referencePlayerView = PlayerView(
            playerID: playerView.playerID,
            objectHandle: playerView.objectHandle,
            roomSourceIndex: 3,
            camera: .trainingRoom3,
            collisionRadius: playerView.collisionRadius
        )
        let visibleFace = try XCTUnwrap(
            try extractWorldForRendering(
                validSuccessor,
                playerView: referencePlayerView
            ).opaqueDrawItems.first
        )
        let roomIndex = try XCTUnwrap(
            validSuccessor.rooms.firstIndex {
                $0.sourceIndex == visibleFace.roomSourceIndex
            }
        )
        let room = validSuccessor.rooms[roomIndex]
        let face = room.faces[visibleFace.faceIndex]
        let materialIndex = try XCTUnwrap(
            validSuccessor.presentationMaterials.firstIndex {
                $0.texture == face.texture
            }
        )
        let material = validSuccessor.presentationMaterials[materialIndex]
        let coronaSource = SourceResource(storedIndex: 0, sourceName: "hostile-flare.ogf")
        let hostileMaterial = PresentationMaterial(
            texture: material.texture,
            bitmapSourceName: material.bitmapSourceName,
            image: material.image,
            blend: material.blend,
            lightmapBlend: material.lightmapBlend,
            waterProcedural: material.waterProcedural,
            lightCorona: .init(
                assetIndex: 0,
                tint: .init(x: 1, y: 1, z: 1),
                blend: .additiveSourceAlpha(opacity: 102)
            ),
            sourceArchive: material.sourceArchive,
            sourceSHA256: material.sourceSHA256
        )
        let coronaAsset = PresentationCoronaAsset(
            source: coronaSource,
            bitmapSourceName: "hostile-flare.ogf",
            image: .init(width: 1, height: 1, rgba8: Data([255, 255, 255, 255])),
            sourceArchive: validSuccessor.source.profileFiles[0].relativePath,
            sourceSHA256: String(repeating: "e", count: 64)
        )
        let hostileFace = replacing(face, allowsLightCorona: true)
        var hostileRooms = validSuccessor.rooms
        var hostileFaces = room.faces
        hostileFaces[visibleFace.faceIndex] = hostileFace
        hostileRooms[roomIndex] = replacing(room, faces: hostileFaces)
        var hostileMaterials = validSuccessor.presentationMaterials
        hostileMaterials[materialIndex] = hostileMaterial
        let hostile = replacing(
            validSuccessor,
            rooms: hostileRooms,
            presentationMaterials: hostileMaterials,
            presentationCoronaAssets: [coronaAsset],
            dependencyManifest: .init(
                current: validSuccessor.dependencyManifest.current + [
                    .init(
                        category: "presentation-effect",
                        source: coronaSource,
                        state: "presentation-payload-imported",
                        provenance: "hostile canonical fixture"
                    ),
                ],
                historicalEagerBaseline: nil
            )
        )
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertEqual(hostile.presentationCoronaAssets, [coronaAsset])
        XCTAssertEqual(
            hostile.presentationMaterials[materialIndex].lightCorona,
            hostileMaterial.lightCorona
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try writeCanonicalPackage(priorLevel, to: priorCandidate)
        let prior = try library.installAndActivate(from: priorCandidate)
        try writeCanonicalPackage(validSuccessor, to: successorCandidate)
        try overwriteCanonicalPackageLevel(hostile, at: successorCandidate)

        let activated = try library.installAndActivate(from: successorCandidate)
        XCTAssertEqual(activated.level, hostile)
        XCTAssertNotEqual(activated, prior)
        XCTAssertEqual(try library.loadActive(), activated)
    }

    func testCanonicalLoaderRejectsNegativeSourceEntryExtentsWithCompleteProvenance() throws {
        let base = makeMinimalCanonicalPackageLevel()
        let completeSource = LevelSource(
            profileIdentifier: base.source.profileIdentifier,
            profileFiles: base.source.profileFiles,
            archiveSHA256: base.source.archiveSHA256,
            levelSHA256: base.source.levelSHA256,
            d3lvVersion: base.source.d3lvVersion,
            archiveEntryName: "training.d3l",
            archiveEntryOffset: 32,
            archiveEntryByteCount: 64,
            referenceChecksum: String(repeating: "c", count: 32),
            referenceChecksumBasis: "pinned-source-provenance-implied-by-exact-level-sha256"
        )
        let validLevel = replacing(base, source: completeSource)
        let invalidSources = [
            replacing(completeSource, archiveEntryOffset: -1),
            replacing(completeSource, archiveEntryByteCount: -1),
        ]

        for invalidSource in invalidSources {
            let temporaryDirectory = FileManager.default.temporaryDirectory
                .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            let package = temporaryDirectory
                .appending(path: "content.revival", directoryHint: .isDirectory)
            defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

            try FileManager.default.createDirectory(
                at: temporaryDirectory,
                withIntermediateDirectories: false
            )
            try writeCanonicalPackage(validLevel, to: package)
            try overwriteCanonicalPackageLevel(
                replacing(validLevel, source: invalidSource),
                at: package
            )

            XCTAssertThrowsError(try loadCanonicalLevel(from: package)) { error in
                XCTAssertEqual(error as? LevelValidationError, .invalidIdentity)
            }
        }
    }

    func testRejectsInvalidMirrorFaceAndCombinedPortalRelationships() throws {
        let level = makeMinimalCanonicalLevel()
        let mirroredRoom = replacing(level.rooms[0], mirrorFaceIndex: 1)
        assertValidationError(
            .invalidMirrorFace(room: level.rooms[0].sourceIndex),
            replacing(level, rooms: [mirroredRoom, level.rooms[1]])
        )

        let combinedRooms = level.rooms.map { room in
            replacing(
                room,
                portals: room.portals.map {
                    replacing($0, flags: 0x0000_0008, combineMaster: 0)
                }
            )
        }
        XCTAssertNoThrow(try replacing(level, rooms: combinedRooms).validate())

        let invalidCombinedRoom = replacing(
            combinedRooms[0],
            portals: [replacing(combinedRooms[0].portals[0], combineMaster: 1)]
        )
        assertValidationError(
            .invalidCombinedPortal(room: level.rooms[0].sourceIndex, portal: 0),
            replacing(level, rooms: [invalidCombinedRoom, combinedRooms[1]])
        )

        let ignoredCombineMasterRooms = level.rooms.map { room in
            replacing(room, portals: room.portals.map { replacing($0, combineMaster: .max) })
        }
        XCTAssertNoThrow(try replacing(level, rooms: ignoredCombineMasterRooms).validate())

        let mismatchedRenderGroupRooms = level.rooms.map { room in
            let firstFace = room.faces[0]
            let secondFace = LevelFace(
                corners: firstFace.corners,
                flags: firstFace.flags,
                portalIndex: 1,
                texture: firstFace.texture
            )
            let firstPortal = room.portals[0]
            let master = replacing(firstPortal, flags: 0x0000_0008, combineMaster: 0)
            let member = LevelPortal(
                flags: 0x0000_0009,
                faceIndex: 1,
                connectedRoom: firstPortal.connectedRoom,
                connectedPortal: 1,
                boundaryNodeIndex: firstPortal.boundaryNodeIndex,
                pathPoint: firstPortal.pathPoint,
                combineMaster: 0
            )
            return replacing(
                room,
                faces: [firstFace, secondFace],
                portals: [master, member]
            )
        }
        assertValidationError(
            .invalidCombinedPortal(room: level.rooms[0].sourceIndex, portal: 1),
            replacing(level, rooms: mismatchedRenderGroupRooms)
        )
    }

    func testRejectsInvalidVolumeLightDimensionsWithoutOverflowing() {
        let level = makeMinimalCanonicalLevel()
        let mismatchedRoom = replacing(
            level.rooms[0],
            volumeLights: .init(width: 2, height: 2, depth: 2, values: [UInt8](repeating: 0, count: 7))
        )
        assertValidationError(
            .invalidVolumeLights(room: level.rooms[0].sourceIndex),
            replacing(level, rooms: [mismatchedRoom, level.rooms[1]])
        )

        let oversizedRoom = replacing(
            level.rooms[0],
            volumeLights: .init(width: .max, height: 2, depth: 2, values: [])
        )
        assertValidationError(
            .invalidVolumeLights(room: level.rooms[0].sourceIndex),
            replacing(level, rooms: [oversizedRoom, level.rooms[1]])
        )
    }

    func testRejectsInvalidLightmapPagesRectanglesAndObjectReferences() {
        let level = makeMinimalCanonicalLevel()
        let pageDependency = DependencyRecord(
            category: "lightmap-page",
            source: .init(storedIndex: 0, sourceName: "lightmap-page-0"),
            state: "payload-validated-preparation-deferred",
            provenance: "synthetic canonical fixture"
        )
        let infoDependency = DependencyRecord(
            category: "lightmap-info",
            source: .init(storedIndex: 0, sourceName: "lightmap-info-0"),
            state: "identity-recorded",
            provenance: "synthetic canonical fixture"
        )
        assertValidationError(
            .invalidLightmapPage(0),
            replacing(
                level,
                lightmaps: .init(pages: [.init(width: 129, height: 1)], infos: []),
                dependencyManifest: .init(
                    current: level.dependencyManifest.current + [pageDependency],
                    historicalEagerBaseline: nil
                )
            )
        )

        let outOfBoundsInfo = LightmapInfoRecord(
            pageIndex: 0,
            width: 2,
            height: 2,
            type: 0,
            x: 3,
            y: 3,
            xSpacing: 0,
            ySpacing: 0,
            upperLeft: .zero,
            normal: .zero
        )
        assertValidationError(
            .invalidLightmapInfo(0),
            replacing(
                level,
                lightmaps: .init(pages: [.init(width: 4, height: 4)], infos: [outOfBoundsInfo]),
                dependencyManifest: .init(
                    current: level.dependencyManifest.current + [pageDependency, infoDependency],
                    historicalEagerBaseline: nil
                )
            )
        )

        let object = makePlacedObject(
            lightmapSubmodels: [
                .init(
                    faces: [
                        .init(
                            lightmapInfoIndex: 0,
                            right: .zero,
                            up: .zero,
                            uv: [.init(u: 0, v: 0)]
                        ),
                    ]
                ),
            ]
        )
        assertValidationError(.invalidLightmapReference(0), replacing(level, objects: [object]))
    }

    func testRejectsMismatchedSpecialNormalsAndTriggerFaceFlags() {
        let level = makeMinimalCanonicalLevel()
        let face = level.rooms[0].faces[0]
        let invalidSpecialFace = replacing(
            face,
            special: .init(
                type: 0,
                points: [],
                smoothedVertexNormals: [.zero, .zero]
            )
        )
        let specialRoom = replacing(level.rooms[0], faces: [invalidSpecialFace])
        assertValidationError(
            .invalidSpecialFace(room: level.rooms[0].sourceIndex, face: 0),
            replacing(level, rooms: [specialRoom, level.rooms[1]])
        )

        let trigger = LevelTrigger(
            name: "missing-face-flag",
            roomIndex: level.rooms[0].sourceIndex,
            faceIndex: 0,
            flags: 0,
            activator: 0
        )
        assertValidationError(
            .invalidTrigger("missing-face-flag"),
            replacing(level, triggers: [trigger])
        )
    }

    func testRejectsInconsistentFaceLightmapRelationships() {
        let level = makeMinimalCanonicalLevel()
        let face = level.rooms[0].faces[0]

        let flaggedWithoutLightmap = replacing(face, flags: face.flags | 0x0001)
        assertValidationError(
            .invalidFace(room: level.rooms[0].sourceIndex, face: 0),
            replacing(
                level,
                rooms: [
                    replacing(level.rooms[0], faces: [flaggedWithoutLightmap]),
                    level.rooms[1],
                ]
            )
        )

        let litCorners = face.corners.map {
            FaceCorner(
                vertexIndex: $0.vertexIndex,
                u: $0.u,
                v: $0.v,
                alpha: $0.alpha,
                lightmapU: 0,
                lightmapV: 0
            )
        }
        let unflaggedWithLightmap = replacing(
            face,
            corners: litCorners,
            lightmapInfoIndex: 0
        )
        let lightmaps = LightmapCatalog(
            pages: [.init(width: 4, height: 4)],
            infos: [
                .init(
                    pageIndex: 0,
                    width: 2,
                    height: 2,
                    type: 0,
                    x: 0,
                    y: 0,
                    xSpacing: 0,
                    ySpacing: 0,
                    upperLeft: .zero,
                    normal: .zero
                ),
            ]
        )
        let lightmapDependencies = DependencyManifest(
            current: level.dependencyManifest.current + [
                .init(
                    category: "lightmap-page",
                    source: .init(storedIndex: 0, sourceName: "lightmap-page-0"),
                    state: "payload-validated-preparation-deferred",
                    provenance: "synthetic canonical fixture"
                ),
                .init(
                    category: "lightmap-info",
                    source: .init(storedIndex: 0, sourceName: "lightmap-info-0"),
                    state: "identity-recorded",
                    provenance: "synthetic canonical fixture"
                ),
            ],
            historicalEagerBaseline: nil
        )
        assertValidationError(
            .invalidFace(room: level.rooms[0].sourceIndex, face: 0),
            replacing(
                level,
                rooms: [
                    replacing(level.rooms[0], faces: [unflaggedWithLightmap]),
                    level.rooms[1],
                ],
                lightmaps: lightmaps,
                dependencyManifest: lightmapDependencies
            )
        )

        var partialCorners = litCorners
        partialCorners[0] = FaceCorner(
            vertexIndex: partialCorners[0].vertexIndex,
            u: partialCorners[0].u,
            v: partialCorners[0].v,
            alpha: partialCorners[0].alpha,
            lightmapU: 0,
            lightmapV: nil
        )
        let partialLightmap = replacing(
            face,
            corners: partialCorners,
            flags: face.flags | 0x0001,
            lightmapInfoIndex: 0
        )
        assertValidationError(
            .invalidFace(room: level.rooms[0].sourceIndex, face: 0),
            replacing(
                level,
                rooms: [
                    replacing(level.rooms[0], faces: [partialLightmap]),
                    level.rooms[1],
                ],
                lightmaps: lightmaps,
                dependencyManifest: lightmapDependencies
            )
        )
    }

    func testRejectsDuplicateOutOfRangeAndRetiredObjectSlots() {
        let level = makeMinimalCanonicalLevel()
        let first = makePlacedObject(handle: 2_049)
        let duplicateSlot = makePlacedObject(handle: 4_097)
        assertValidationError(
            .invalidObjectHandle(4_097),
            replacing(level, objects: [first, duplicateSlot])
        )
        assertValidationError(
            .invalidObjectHandle(3_548),
            replacing(level, objects: [makePlacedObject(handle: 3_548)])
        )
        assertValidationError(
            .invalidObjectHandle(3_548),
            replacing(level, retiredObjectHandles: [3_548])
        )
        assertValidationError(
            .invalidObjectHandle(4_097),
            replacing(level, objects: [first], retiredObjectHandles: [4_097])
        )
    }

    func testRejectsObjectLocationInAnExternalRoomInsteadOfRelocatingIt() {
        let level = makeMinimalCanonicalLevel()
        let externalRoom = replacing(level.rooms[0], flags: level.rooms[0].flags | 0x0000_0004)
        assertValidationError(
            .invalidLocation,
            replacing(
                level,
                rooms: [externalRoom, level.rooms[1]],
                objects: [makePlacedObject(location: .room(externalRoom.sourceIndex))]
            )
        )
    }

    func testRejectsImpossibleObjectSourceIdentities() {
        let level = makeMinimalCanonicalLevel()
        assertValidationError(
            .invalidObjectHandle(0),
            replacing(level, objects: [makePlacedObject(handle: 0)])
        )
        assertValidationError(
            .invalidObjectHandle(1),
            replacing(level, objects: [makePlacedObject(handle: 1)])
        )
        assertValidationError(
            .invalidObjectType(18),
            replacing(level, objects: [makePlacedObject(type: 18)])
        )
        assertValidationError(
            .invalidObjectType(26),
            replacing(level, objects: [makePlacedObject(type: 26)])
        )
        assertValidationError(
            .invalidObjectStoredID(handle: 2_048, storedID: 32_768),
            replacing(level, objects: [makePlacedObject(storedID: 32_768)])
        )
    }

    func testRejectsResourceIndicesBeyondSourceTableCeilings() {
        let level = makeMinimalCanonicalLevel()
        let cases = [
            (category: "texture", source: SourceResource(storedIndex: 3_100, sourceName: "texture")),
            (
                category: "object-definition",
                source: SourceResource(storedIndex: 910, sourceName: "object")
            ),
            (
                category: "door-definition",
                source: SourceResource(storedIndex: 60, sourceName: "door")
            ),
        ]
        for value in cases {
            let orphan = DependencyRecord(
                category: value.category,
                source: value.source,
                state: "identity-recorded",
                provenance: "synthetic canonical fixture"
            )
            assertValidationError(
                .invalidSourceResource(
                    category: value.category,
                    storedIndex: value.source.storedIndex
                ),
                replacing(
                    level,
                    dependencyManifest: .init(
                        current: level.dependencyManifest.current + [orphan],
                        historicalEagerBaseline: nil
                    )
                )
            )
        }
    }

    func testRejectsUsesThrustPlayerShipWithoutPositiveDrag() {
        let level = makeSliceSixObjectRenderLevel()
        let ship = level.shipDefinitions[0]
        let physics = ship.physics
        let zeroDrag = CanonicalShipPhysics(
            mass: physics.mass,
            drag: 0,
            fullThrust: physics.fullThrust,
            behaviors: physics.behaviors,
            rotationalDrag: physics.rotationalDrag,
            fullRotationalThrust: physics.fullRotationalThrust,
            numberOfBounces: physics.numberOfBounces,
            initialForwardVelocity: physics.initialForwardVelocity,
            initialAngularVelocity: physics.initialAngularVelocity,
            wiggleAmplitude: physics.wiggleAmplitude,
            wigglesPerSecond: physics.wigglesPerSecond,
            coefficientOfRestitution: physics.coefficientOfRestitution,
            hitDieDot: physics.hitDieDot,
            maximumTurnrollRate: physics.maximumTurnrollRate,
            turnrollRatio: physics.turnrollRatio
        )

        assertValidationError(
            .invalidDependency("default player ship physics"),
            replacing(
                level,
                shipDefinitions: [
                    .init(
                        source: ship.source,
                        primaryModel: ship.primaryModel,
                        presentationSize: ship.presentationSize,
                        physics: zeroDrag
                    ),
                ]
            )
        )
    }

    func testRejectsDegenerateCanonicalObjectOrientation() {
        let level = makeMinimalCanonicalLevel()
        let object = makePlacedObject(
            orientation: .init(right: .zero, up: .zero, forward: .zero)
        )
        assertValidationError(
            .invalidObjectOrientation(object.handle),
            replacing(level, objects: [object])
        )
    }

    func testRejectsUnresolvedOrRemappedGoalObjectHandle() {
        let level = makeMinimalCanonicalLevel()
        let sourceObject = makePlacedObject(handle: 2_048)
        let otherObject = makePlacedObject(handle: 2_049)
        func goal(type: UInt8 = 2, objectHandle: UInt32?) -> LevelGoal {
            LevelGoal(
                status: 0,
                priority: 0,
                list: 0,
                name: "goal",
                itemName: "item",
                description: "",
                completionMessage: "",
                items: [
                    .init(
                        type: type,
                        sourceHandle: sourceObject.handle,
                        objectHandle: objectHandle,
                        done: false
                    ),
                ]
            )
        }

        assertValidationError(
            .invalidGoalObject(sourceObject.handle),
            replacing(
                level,
                objects: [sourceObject, otherObject],
                goals: [goal(objectHandle: nil)]
            )
        )
        assertValidationError(
            .invalidGoalObject(sourceObject.handle),
            replacing(
                level,
                objects: [sourceObject, otherObject],
                goals: [goal(objectHandle: otherObject.handle)]
            )
        )
        assertValidationError(
            .invalidGoalObject(sourceObject.handle),
            replacing(
                level,
                objects: [sourceObject, otherObject],
                goals: [goal(type: 0, objectHandle: sourceObject.handle)]
            )
        )
    }

    func testRetainsEveryStoredObjectIDAndOnlyAttachesDefinitionBearingTypes() throws {
        let level = makeMinimalCanonicalLevel()
        let viewer = makePlacedObject(type: 6, storedID: 20)
        let genericDefinition = SourceResource(storedIndex: 4, sourceName: "robot")
        let generic = makePlacedObject(
            handle: 2_049,
            type: 2,
            storedID: 4,
            definition: genericDefinition
        )
        let valid = replacing(
            level,
            objects: [viewer, generic],
            dependencyManifest: .init(
                current: level.dependencyManifest.current + [
                    .init(
                        category: "object-definition",
                        source: genericDefinition,
                        state: "identity-recorded",
                        provenance: "synthetic canonical fixture"
                    ),
                ],
                historicalEagerBaseline: nil
            )
        )

        XCTAssertNoThrow(try valid.validate())
        XCTAssertEqual(valid.objects[0].storedID, 20)
        XCTAssertNil(valid.objects[0].definition)
        XCTAssertEqual(valid.objects[1].definition, genericDefinition)
        assertValidationError(
            .invalidObjectDefinition(2_048),
            replacing(
                level,
                objects: [makePlacedObject(type: 2, storedID: 4, definition: nil)]
            )
        )
        let fabricatedDefinition = SourceResource(
            storedIndex: 20,
            sourceName: "fabricated-viewer-name"
        )
        assertValidationError(
            .invalidObjectDefinition(2_048),
            replacing(
                level,
                objects: [
                    makePlacedObject(
                        type: 6,
                        storedID: 20,
                        definition: fabricatedDefinition
                    ),
                ],
                dependencyManifest: .init(
                    current: level.dependencyManifest.current + [
                        .init(
                            category: "object-definition",
                            source: fabricatedDefinition,
                            state: "identity-recorded",
                            provenance: "synthetic canonical fixture"
                        ),
                    ],
                    historicalEagerBaseline: nil
                )
            )
        )
    }

    func testRejectsMalformedOrDuplicateSourceAndDependencyMetadata() {
        let level = makeMinimalCanonicalLevel()
        let validHash = String(repeating: "a", count: 64)
        let validChunk = SourceChunkRecord(
            name: "ROOM",
            byteCount: 1,
            sha256: validHash,
            disposition: "canonical-topology"
        )
        assertValidationError(.invalidSourceChunk("missing"), replacing(level, sourceChunks: []))
        let malformedChunks = [
            SourceChunkRecord(
                name: "",
                byteCount: 1,
                sha256: validHash,
                disposition: "canonical-topology"
            ),
            SourceChunkRecord(
                name: "ROOM",
                byteCount: -1,
                sha256: validHash,
                disposition: "canonical-topology"
            ),
            SourceChunkRecord(
                name: "ROOM",
                byteCount: 1,
                sha256: "bad",
                disposition: "canonical-topology"
            ),
            SourceChunkRecord(
                name: "ROOM",
                byteCount: 1,
                sha256: validHash,
                disposition: ""
            ),
        ]
        for chunk in malformedChunks {
            assertValidationError(
                .invalidSourceChunk(chunk.name),
                replacing(level, sourceChunks: [chunk])
            )
        }
        assertValidationError(
            .invalidSourceChunk("ROOM"),
            replacing(level, sourceChunks: [validChunk, validChunk])
        )

        let extraDependency = DependencyRecord(
            category: "texture",
            source: .init(storedIndex: 1, sourceName: "wall-1"),
            state: "identity-recorded",
            provenance: "TXNM"
        )
        let malformedDependency = DependencyRecord(
            category: extraDependency.category,
            source: extraDependency.source,
            state: "",
            provenance: extraDependency.provenance
        )
        assertValidationError(
            .invalidDependency("texture"),
            replacing(
                level,
                dependencyManifest: .init(
                    current: level.dependencyManifest.current + [malformedDependency],
                    historicalEagerBaseline: nil
                )
            )
        )
        assertValidationError(
            .duplicateDependency,
            replacing(
                level,
                dependencyManifest: .init(
                    current: level.dependencyManifest.current + [
                        extraDependency,
                        extraDependency,
                    ],
                    historicalEagerBaseline: nil
                )
            )
        )
        assertValidationError(
            .duplicateDependency,
            replacing(
                level,
                dependencyManifest: .init(
                    current: level.dependencyManifest.current + [
                        extraDependency,
                        .init(
                            category: "texture",
                            source: .init(storedIndex: 1, sourceName: "wall-alias"),
                            state: "identity-recorded",
                            provenance: "TXNM"
                        ),
                    ],
                    historicalEagerBaseline: nil
                )
            )
        )
    }

    func testRejectsSourceIdentityThatCannotProveTheAcceptedRetailBytes() {
        let level = makeMinimalCanonicalLevel()
        let source = level.source
        let duplicateFingerprint = source.profileFiles[0]
        let invalidSources = [
            replacing(source, profileIdentifier: ""),
            replacing(source, profileFiles: []),
            replacing(
                source,
                profileFiles: [
                    duplicateFingerprint,
                    duplicateFingerprint,
                ]
            ),
            replacing(
                source,
                profileFiles: [
                    .init(
                        relativePath: "../training.mn3",
                        byteCount: duplicateFingerprint.byteCount,
                        sha256: duplicateFingerprint.sha256
                    ),
                ]
            ),
            replacing(
                source,
                profileFiles: [
                    .init(
                        relativePath: duplicateFingerprint.relativePath,
                        byteCount: -1,
                        sha256: duplicateFingerprint.sha256
                    ),
                ]
            ),
            replacing(
                source,
                profileFiles: [
                    .init(
                        relativePath: duplicateFingerprint.relativePath,
                        byteCount: duplicateFingerprint.byteCount,
                        sha256: "bad"
                    ),
                ]
            ),
            replacing(source, archiveSHA256: "bad"),
            replacing(source, levelSHA256: "bad"),
            replacing(
                source,
                referenceChecksum: "not-a-32-character-lowercase-hash",
                referenceChecksumBasis: "pinned-source-provenance-implied-by-exact-level-sha256"
            ),
        ]

        for invalidSource in invalidSources {
            assertValidationError(.invalidIdentity, replacing(level, source: invalidSource))
        }
    }

    func testRejectsSourceSchemaCountsBeyondTheLegacyCeilings() {
        let level = makeMinimalCanonicalLevel()
        let bareRoom = LevelRoom(sourceIndex: 0, vertices: [], faces: [], portals: [])
        assertValidationError(
            .invalidCount("rooms"),
            replacing(level, rooms: [LevelRoom](repeating: bareRoom, count: 401))
        )
        assertValidationError(
            .invalidCount("rooms"),
            replacing(
                level,
                rooms: [LevelRoom(sourceIndex: 400, vertices: [], faces: [], portals: [])]
            )
        )
        assertValidationError(
            .invalidCount("room 0"),
            replacing(
                level,
                rooms: [
                    LevelRoom(
                        sourceIndex: 0,
                        vertices: [Vector3](repeating: .zero, count: 10_001),
                        faces: [],
                        portals: []
                    ),
                ]
            )
        )

        let corners = [
            FaceCorner(vertexIndex: 0, u: 0, v: 0, alpha: 255),
            FaceCorner(vertexIndex: 1, u: 0, v: 0, alpha: 255),
            FaceCorner(vertexIndex: 2, u: 0, v: 0, alpha: 255),
        ]
        let face = LevelFace(
            corners: corners,
            flags: 0,
            portalIndex: nil,
            texture: .init(storedIndex: 0, sourceName: "wall")
        )
        assertValidationError(
            .invalidCount("room 0"),
            replacing(
                level,
                rooms: [
                    LevelRoom(
                        sourceIndex: 0,
                        vertices: [.zero, .zero, .zero],
                        faces: [LevelFace](repeating: face, count: 3_001),
                        portals: []
                    ),
                ]
            )
        )
        assertValidationError(
            .invalidFace(room: 0, face: 0),
            replacing(
                level,
                rooms: [
                    LevelRoom(
                        sourceIndex: 0,
                        vertices: [.zero],
                        faces: [
                            .init(
                                corners: [FaceCorner](
                                    repeating: .init(vertexIndex: 0, u: 0, v: 0, alpha: 255),
                                    count: 65
                                ),
                                flags: 0,
                                portalIndex: nil,
                                texture: .init(storedIndex: 0, sourceName: "wall")
                            ),
                        ],
                        portals: []
                    ),
                ]
            )
        )
        assertValidationError(
            .invalidCount("objects"),
            replacing(
                level,
                objects: (0...1_500).map {
                    makePlacedObject(handle: UInt32(0x800 + $0))
                }
            )
        )
        assertValidationError(
            .invalidCount("paths"),
            replacing(
                level,
                paths: [GamePath](repeating: .init(name: "path", flags: 0, nodes: []), count: 301)
            )
        )
        let pathNode = GamePathNode(
            position: .zero,
            location: .room(level.rooms[0].sourceIndex),
            flags: 0,
            forward: .zero,
            up: .zero
        )
        assertValidationError(
            .invalidCount("path nodes"),
            replacing(
                level,
                paths: [.init(name: "path", flags: 0, nodes: [GamePathNode](repeating: pathNode, count: 101))]
            )
        )
        let goal = LevelGoal(
            status: 0,
            priority: 0,
            list: 0,
            name: "goal",
            itemName: "",
            description: "",
            completionMessage: "",
            items: []
        )
        assertValidationError(
            .invalidCount("goals"),
            replacing(level, goals: [LevelGoal](repeating: goal, count: 33))
        )
        let goalObject = makePlacedObject()
        let goalItem = LevelGoalItem(
            type: 2,
            sourceHandle: goalObject.handle,
            objectHandle: goalObject.handle,
            done: false
        )
        assertValidationError(
            .invalidCount("goal items"),
            replacing(
                level,
                objects: [goalObject],
                goals: [
                    .init(
                        status: 0,
                        priority: 0,
                        list: 0,
                        name: "goal",
                        itemName: "",
                        description: "",
                        completionMessage: "",
                        items: [LevelGoalItem](repeating: goalItem, count: 13)
                    ),
                ]
            )
        )
        let satellite = TerrainSatellite(
            texture: .init(storedIndex: 0, sourceName: "wall"),
            vector: .zero,
            flags: 0,
            size: 0,
            red: 0,
            green: 0,
            blue: 0
        )
        let sky = TerrainSky(
            fogScalar: 0,
            damagePerSecond: 0,
            textured: false,
            domeTexture: .init(storedIndex: 0, sourceName: "wall"),
            skyColor: 0,
            horizonColor: 0,
            fogColor: 0,
            flags: 0,
            radius: 0,
            rotationRate: 0,
            satellites: [TerrainSatellite](repeating: satellite, count: 6)
        )
        assertValidationError(
            .invalidCount("terrain satellites"),
            replacing(level, terrain: replacing(level.terrain, sky: sky))
        )
        assertValidationError(
            .invalidCount("player start flags"),
            replacing(level, playerStartFlags: [UInt32](repeating: 0, count: 33))
        )
        XCTAssertNoThrow(try replacing(level, rooms: [bareRoom]).validate())
    }

    func testRejectsLightmapVolumeAndPortalCountsThatBypassDecoderLimits() {
        let level = makeMinimalCanonicalLevel()
        assertValidationError(
            .invalidCount("lightmap pages"),
            replacing(
                level,
                lightmaps: .init(
                    pages: [LightmapPageMetadata](
                        repeating: .init(width: 1, height: 1),
                        count: 65_535
                    ),
                    infos: []
                )
            )
        )

        var sourceMaximumPages = [LightmapPageMetadata](
            repeating: .init(width: 1, height: 1),
            count: 65_534
        )
        sourceMaximumPages[0] = .init(width: 129, height: 1)
        assertValidationError(
            .invalidLightmapPage(0),
            replacing(
                level,
                lightmaps: .init(pages: sourceMaximumPages, infos: [])
            )
        )

        let info = LightmapInfoRecord(
            pageIndex: 0,
            width: 2,
            height: 2,
            type: 0,
            x: 0,
            y: 0,
            xSpacing: 0,
            ySpacing: 0,
            upperLeft: .zero,
            normal: .zero
        )
        assertValidationError(
            .invalidCount("lightmap infos"),
            replacing(
                level,
                lightmaps: .init(
                    pages: [.init(width: 2, height: 2)],
                    infos: [LightmapInfoRecord](repeating: info, count: 65_534)
                )
            )
        )

        let wideVolumeRoom = replacing(
            level.rooms[0],
            volumeLights: .init(width: 256, height: 0, depth: 0, values: [])
        )
        XCTAssertNoThrow(
            try replacing(level, rooms: [wideVolumeRoom, level.rooms[1]]).validate()
        )

        let oversizedVolumeRoom = replacing(
            level.rooms[0],
            volumeLights: .init(width: 32_768, height: 0, depth: 0, values: [])
        )
        assertValidationError(
            .invalidVolumeLights(room: level.rooms[0].sourceIndex),
            replacing(level, rooms: [oversizedVolumeRoom, level.rooms[1]])
        )

        let tooManyPortalsRoom = replacing(
            level.rooms[0],
            portals: [level.rooms[0].portals[0], level.rooms[0].portals[0]]
        )
        assertValidationError(
            .invalidPortal(room: level.rooms[0].sourceIndex, portal: 1),
            replacing(level, rooms: [tooManyPortalsRoom, level.rooms[1]])
        )
    }

    func testRejectsLightmapInfoBelowSourceMinimumDimensions() {
        let level = makeMinimalCanonicalLevel()
        let undersizedInfo = LightmapInfoRecord(
            pageIndex: 0,
            width: 1,
            height: 2,
            type: 0,
            x: 0,
            y: 0,
            xSpacing: 0,
            ySpacing: 0,
            upperLeft: .zero,
            normal: .zero
        )
        assertValidationError(
            .invalidLightmapInfo(0),
            replacing(
                level,
                lightmaps: .init(
                    pages: [.init(width: 4, height: 4)],
                    infos: [undersizedInfo]
                )
            )
        )
    }

    func testRejectsTriggerCountBeyondSourceMaximum() {
        let level = makeMinimalCanonicalLevel()
        let triggerFace = replacing(level.rooms[0].faces[0], flags: 0x0010)
        let triggerRoom = replacing(level.rooms[0], faces: [triggerFace])
        let rooms = [triggerRoom, level.rooms[1]]
        let trigger = LevelTrigger(
            name: "source-trigger",
            roomIndex: triggerRoom.sourceIndex,
            faceIndex: 0,
            flags: 0,
            activator: 0
        )

        assertValidationError(
            .invalidCount("triggers"),
            replacing(
                level,
                rooms: rooms,
                triggers: [LevelTrigger](repeating: trigger, count: 101)
            )
        )
    }

    func testRequiresDependencyClosureForEveryCurrentCanonicalReference() {
        let level = makeMinimalCanonicalLevel()
        let emptyManifest = DependencyManifest(current: [], historicalEagerBaseline: nil)
        assertValidationError(
            .invalidDependency("missing texture:wall"),
            replacing(level, dependencyManifest: emptyManifest)
        )

        let lightmaps = LightmapCatalog(
            pages: [.init(width: 4, height: 4)],
            infos: [
                .init(
                    pageIndex: 0,
                    width: 2,
                    height: 2,
                    type: 0,
                    x: 0,
                    y: 0,
                    xSpacing: 0,
                    ySpacing: 0,
                    upperLeft: .zero,
                    normal: .zero
                ),
            ]
        )
        assertValidationError(
            .invalidDependency("missing lightmap-info:lightmap-info-0"),
            replacing(level, lightmaps: lightmaps, dependencyManifest: emptyManifest)
        )

        let definition = SourceResource(storedIndex: 4, sourceName: "robot")
        let object = makePlacedObject(type: 2, storedID: 4, definition: definition)
        assertValidationError(
            .invalidDependency("missing object-definition:robot"),
            replacing(level, objects: [object], dependencyManifest: emptyManifest)
        )

        let completeDependencies = DependencyManifest(
            current: level.dependencyManifest.current + [
                .init(
                    category: "lightmap-page",
                    source: .init(storedIndex: 0, sourceName: "lightmap-page-0"),
                    state: "payload-validated-preparation-deferred",
                    provenance: "NLMP page metadata"
                ),
                .init(
                    category: "lightmap-info",
                    source: .init(storedIndex: 0, sourceName: "lightmap-info-0"),
                    state: "identity-recorded",
                    provenance: "NLMP metadata"
                ),
                .init(
                    category: "object-definition",
                    source: definition,
                    state: "identity-recorded",
                    provenance: "OBJS placed object"
                ),
            ],
            historicalEagerBaseline: nil
        )
        XCTAssertNoThrow(
            try replacing(
                level,
                objects: [object],
                lightmaps: lightmaps,
                dependencyManifest: completeDependencies
            ).validate()
        )
    }
}

private func makeIndoorTraceLevel(portalFlags: UInt32) -> Level {
    let base = makeMinimalCanonicalLevel()
    let texture = base.rooms[0].faces[0].texture
    let portalFace: ([Vector3], Int) -> (vertices: [Vector3], face: LevelFace) = {
        points, portalIndex in
        (
            points,
            LevelFace(
                corners: points.indices.map {
                    .init(vertexIndex: $0, u: 0, v: 0, alpha: 255)
                },
                flags: 0,
                portalIndex: portalIndex,
                texture: texture
            )
        )
    }
    let room10Portal = portalFace(
        [
            .init(x: 1, y: -1, z: -1),
            .init(x: 1, y: -1, z: 1),
            .init(x: 1, y: 1, z: 1),
            .init(x: 1, y: 1, z: -1),
        ],
        0
    )
    let room20Portal = portalFace(Array(room10Portal.vertices.reversed()), 0)
    let room10 = LevelRoom(
        sourceIndex: 10,
        vertices: room10Portal.vertices,
        faces: [room10Portal.face],
        portals: [
            .init(
                flags: portalFlags,
                faceIndex: 0,
                connectedRoom: 20,
                connectedPortal: 0
            ),
        ]
    )
    let room20 = LevelRoom(
        sourceIndex: 20,
        vertices: room20Portal.vertices,
        faces: [room20Portal.face],
        portals: [
            .init(
                flags: portalFlags,
                faceIndex: 0,
                connectedRoom: 10,
                connectedPortal: 0
            ),
        ]
    )
    return replacing(base, rooms: [room10, room20])
}

private func makeIndoorTraceLevelWithNearWall() -> Level {
    let base = makeIndoorTraceLevel(portalFlags: 0)
    let originalRoom20 = base.rooms[1]
    let firstVertex = originalRoom20.vertices.count
    let vertices = originalRoom20.vertices + [
        .init(x: 1.1, y: -1, z: -1),
        .init(x: 1.1, y: -1, z: 1),
        .init(x: 1.1, y: 1, z: 1),
        .init(x: 1.1, y: 1, z: -1),
    ]
    let wall = LevelFace(
        corners: (0..<4).map {
            .init(vertexIndex: firstVertex + $0, u: 0, v: 0, alpha: 255)
        },
        flags: 0,
        portalIndex: nil,
        texture: originalRoom20.faces[0].texture
    )
    let room20 = LevelRoom(
        sourceIndex: originalRoom20.sourceIndex,
        name: originalRoom20.name,
        pathPoint: originalRoom20.pathPoint,
        vertices: vertices,
        faces: originalRoom20.faces + [wall],
        portals: originalRoom20.portals,
        flags: originalRoom20.flags,
        pulseTime: originalRoom20.pulseTime,
        pulseOffset: originalRoom20.pulseOffset,
        mirrorFaceIndex: originalRoom20.mirrorFaceIndex,
        door: originalRoom20.door,
        volumeLights: originalRoom20.volumeLights,
        fog: originalRoom20.fog,
        ambientSoundPattern: originalRoom20.ambientSoundPattern,
        reverb: originalRoom20.reverb,
        damage: originalRoom20.damage,
        damageType: originalRoom20.damageType
    )
    return replacing(base, rooms: [base.rooms[0], room20])
}

private func makeNonPortalTraceLevel(
    behavior: SurfacePhysicsBehavior
) -> Level {
    let base = makeIndoorTraceLevel(portalFlags: 0x0000_0001)
    let originalRoom = base.rooms[0]
    let originalFace = originalRoom.faces[0]
    let face = LevelFace(
        corners: originalFace.corners,
        flags: originalFace.flags,
        portalIndex: nil,
        texture: originalFace.texture,
        lightmapInfoIndex: originalFace.lightmapInfoIndex,
        allowsLightCorona: originalFace.allowsLightCorona,
        lightMultiple: originalFace.lightMultiple,
        special: originalFace.special
    )
    let room = LevelRoom(
        sourceIndex: originalRoom.sourceIndex,
        name: originalRoom.name,
        pathPoint: originalRoom.pathPoint,
        vertices: originalRoom.vertices,
        faces: [face],
        portals: [],
        flags: originalRoom.flags,
        pulseTime: originalRoom.pulseTime,
        pulseOffset: originalRoom.pulseOffset,
        mirrorFaceIndex: originalRoom.mirrorFaceIndex,
        door: originalRoom.door,
        volumeLights: originalRoom.volumeLights,
        fog: originalRoom.fog,
        ambientSoundPattern: originalRoom.ambientSoundPattern,
        reverb: originalRoom.reverb,
        damage: originalRoom.damage,
        damageType: originalRoom.damageType
    )
    return replacing(
        base,
        rooms: [room],
        surfacePhysics: [
            .init(texture: face.texture, behavior: behavior),
        ]
    )
}

private func assertValidationError(
    _ expected: LevelValidationError,
    _ level: Level,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertThrowsError(try level.validate(), file: file, line: line) { error in
        XCTAssertEqual(error as? LevelValidationError, expected, file: file, line: line)
    }
}

private func overwriteCanonicalPackageLevel(_ level: Level, at packageURL: URL) throws {
    let levelData = try canonicalJSONData(level)
    try overwriteCanonicalPackageLevelData(
        levelData,
        identity: level,
        at: packageURL
    )
}

private func overwriteCanonicalPackageLevelData(
    _ levelData: Data,
    identity level: Level,
    at packageURL: URL
) throws {
    let manifestURL = packageURL.appending(path: "content.json")
    let currentManifest = try JSONDecoder().decode(
        CanonicalPackageManifest.self,
        from: Data(contentsOf: manifestURL)
    )
    let currentLevel = currentManifest.levels[0]
    let manifest = CanonicalPackageManifest(
        packageSchemaVersion: currentManifest.packageSchemaVersion,
        importerContractVersion: currentManifest.importerContractVersion,
        profileIdentifier: level.source.profileIdentifier,
        acceptedSourceFiles: level.source.profileFiles,
        campaigns: currentManifest.campaigns,
        levels: [
            .init(
                levelKey: currentLevel.levelKey,
                relativePath: currentLevel.relativePath,
                sha256: canonicalSHA256(levelData)
            ),
        ],
        translatedFeatureCoverage: currentManifest.translatedFeatureCoverage,
        deferredFeatureCoverage: currentManifest.deferredFeatureCoverage,
        source: level.source,
        sourceEntries: level.sourceChunks,
        currentDependencies: level.dependencyManifest.current,
        rights: currentManifest.rights
    )

    try levelData.write(
        to: packageURL.appending(path: "levels/\(level.levelKey)/level.json")
    )
    try canonicalJSONData(manifest).write(to: manifestURL)
}

func replacing(
    _ level: Level,
    schemaVersion: Int? = nil,
    missionKey: String? = nil,
    levelKey: String? = nil,
    source: LevelSource? = nil,
    metadata: LevelMetadata? = nil,
    rooms: [LevelRoom]? = nil,
    terrain: LevelTerrain? = nil,
    objects: [PlacedObject]? = nil,
    retiredObjectHandles: [UInt32]? = nil,
    paths: [GamePath]? = nil,
    goals: [LevelGoal]? = nil,
    triggers: [LevelTrigger]? = nil,
    playerStartFlags: [UInt32]? = nil,
    indoorNavigation: IndoorNavigationGraph? = nil,
    lightmaps: LightmapCatalog? = nil,
    surfacePhysics: [SurfacePhysicsEntry]? = nil,
    presentationMaterials: [PresentationMaterial]? = nil,
    presentationCoronaAssets: [PresentationCoronaAsset]? = nil,
    models: [CanonicalModel]? = nil,
    shipDefinitions: [CanonicalShipDefinition]? = nil,
    defaultPlayerBinding: DefaultPlayerBinding? = nil,
    objectPresentations: [ObjectPresentationReference]? = nil,
    trainingOpeningLesson: TrainingOpeningLesson? = nil,
    trainingGalleryBarrier: TrainingGalleryBarrier? = nil,
    trainingRobotGuidebotChain: TrainingRobotGuidebotChain? = nil,
    trainingCameraMonitorChain: TrainingCameraMonitorChain? = nil,
    trainingRASBot1DeathChain: TrainingRASBot1DeathChain? = nil,
    trainingRASBot2DeathChain: TrainingRASBot2DeathChain? = nil,
    trainingRASBot3DeathChain: TrainingRASBot3DeathChain? = nil,
    trainingRASBot4DeathChain: TrainingRASBot4DeathChain? = nil,
    trainingLastBot1DeathChain: TrainingLastBot1DeathChain? = nil,
    trainingLastBot3DeathChain: TrainingLastBot3DeathChain? = nil,
    trainingLastBot4DeathChain: TrainingLastBot4DeathChain? = nil,
    trainingLastBot5DeathChain: TrainingLastBot5DeathChain? = nil,
    trainingInvulnerabilityPickupChain:
        TrainingInvulnerabilityPickupChain? = nil,
    trainingCloakPickupChain: TrainingCloakPickupChain? = nil,
    trainingLastRoomChain: TrainingLastRoomChain? = nil,
    trainingFinalRoomEntryChain: TrainingFinalRoomEntryChain? = nil,
    trainingFinalBotsCompletionChain:
        TrainingFinalBotsCompletionChain? = nil,
    voiceClips: [CanonicalVoiceClip]? = nil,
    soundClips: [CanonicalSoundClip]? = nil,
    dependencyManifest: DependencyManifest? = nil,
    sourceChunks: [SourceChunkRecord]? = nil
) -> Level {
    var replaced = Level(
        schemaVersion: schemaVersion ?? level.schemaVersion,
        missionKey: missionKey ?? level.missionKey,
        levelKey: levelKey ?? level.levelKey,
        source: source ?? level.source,
        metadata: metadata ?? level.metadata,
        rooms: rooms ?? level.rooms,
        terrain: terrain ?? level.terrain,
        objects: objects ?? level.objects,
        retiredObjectHandles: retiredObjectHandles ?? level.retiredObjectHandles,
        paths: paths ?? level.paths,
        goals: goals ?? level.goals,
        goalFlags: level.goalFlags,
        triggers: triggers ?? level.triggers,
        playerStartFlags: playerStartFlags ?? level.playerStartFlags,
        indoorNavigation: indoorNavigation ?? level.indoorNavigation,
        lightmaps: lightmaps ?? level.lightmaps,
        surfacePhysics: surfacePhysics ?? rooms.map { candidateRooms in
            Set(candidateRooms.flatMap { $0.faces.map(\.texture) }).sorted {
                if $0.storedIndex != $1.storedIndex {
                    return $0.storedIndex < $1.storedIndex
                }
                return $0.sourceName < $1.sourceName
            }.map { .init(texture: $0, behavior: .blocking) }
        } ?? level.surfacePhysics,
        presentationMaterials: presentationMaterials ?? level.presentationMaterials,
        presentationCoronaAssets: presentationCoronaAssets ?? level.presentationCoronaAssets,
        models: models ?? level.models,
        shipDefinitions: shipDefinitions ?? level.shipDefinitions,
        defaultPlayerBinding: defaultPlayerBinding ?? level.defaultPlayerBinding,
        objectPresentations: objectPresentations ?? level.objectPresentations,
        trainingOpeningLesson:
            trainingOpeningLesson ?? level.trainingOpeningLesson,
        trainingGalleryBarrier:
            trainingGalleryBarrier ?? level.trainingGalleryBarrier,
        trainingRobotGuidebotChain:
            trainingRobotGuidebotChain ?? level.trainingRobotGuidebotChain,
        trainingCameraMonitorChain:
            trainingCameraMonitorChain ?? level.trainingCameraMonitorChain,
        trainingRASBot1DeathChain:
            trainingRASBot1DeathChain ?? level.trainingRASBot1DeathChain,
        trainingRASBot2DeathChain:
            trainingRASBot2DeathChain ?? level.trainingRASBot2DeathChain,
        trainingRASBot3DeathChain:
            trainingRASBot3DeathChain ?? level.trainingRASBot3DeathChain,
        trainingRASBot4DeathChain:
            trainingRASBot4DeathChain ?? level.trainingRASBot4DeathChain,
        trainingLastBot1DeathChain:
            trainingLastBot1DeathChain ?? level.trainingLastBot1DeathChain,
        trainingInvulnerabilityPickupChain:
            trainingInvulnerabilityPickupChain
            ?? level.trainingInvulnerabilityPickupChain,
        trainingCloakPickupChain:
            trainingCloakPickupChain ?? level.trainingCloakPickupChain,
        trainingLastRoomChain:
            trainingLastRoomChain ?? level.trainingLastRoomChain,
        trainingFinalRoomEntryChain:
            trainingFinalRoomEntryChain
            ?? level.trainingFinalRoomEntryChain,
        trainingFinalBotsCompletionChain:
            trainingFinalBotsCompletionChain
            ?? level.trainingFinalBotsCompletionChain,
        voiceClips: voiceClips ?? level.voiceClips,
        soundClips: soundClips ?? level.soundClips,
        dependencyManifest: dependencyManifest ?? level.dependencyManifest,
        sourceChunks: sourceChunks ?? level.sourceChunks
    )
    replaced.trainingLastBot2DeathChain =
        level.trainingLastBot2DeathChain
    replaced.trainingLastBot3DeathChain =
        trainingLastBot3DeathChain ?? level.trainingLastBot3DeathChain
    replaced.trainingLastBot4DeathChain =
        trainingLastBot4DeathChain ?? level.trainingLastBot4DeathChain
    replaced.trainingLastBot5DeathChain =
        trainingLastBot5DeathChain ?? level.trainingLastBot5DeathChain
    replaced.trainingFinalBotsCompletionChain =
        trainingFinalBotsCompletionChain
        ?? level.trainingFinalBotsCompletionChain
    return replaced
}

func replacing(
    _ source: LevelSource,
    profileIdentifier: String? = nil,
    profileFiles: [SourceFileFingerprint]? = nil,
    archiveSHA256: String? = nil,
    levelSHA256: String? = nil,
    archiveEntryOffset: Int? = nil,
    archiveEntryByteCount: Int? = nil,
    referenceChecksum: String? = nil,
    referenceChecksumBasis: String? = nil
) -> LevelSource {
    LevelSource(
        profileIdentifier: profileIdentifier ?? source.profileIdentifier,
        profileFiles: profileFiles ?? source.profileFiles,
        archiveSHA256: archiveSHA256 ?? source.archiveSHA256,
        levelSHA256: levelSHA256 ?? source.levelSHA256,
        d3lvVersion: source.d3lvVersion,
        archiveEntryName: source.archiveEntryName,
        archiveEntryOffset: archiveEntryOffset ?? source.archiveEntryOffset,
        archiveEntryByteCount: archiveEntryByteCount ?? source.archiveEntryByteCount,
        referenceChecksum: referenceChecksum ?? source.referenceChecksum,
        referenceChecksumBasis: referenceChecksumBasis ?? source.referenceChecksumBasis
    )
}

func replacing(
    _ room: LevelRoom,
    sourceIndex: Int? = nil,
    vertices: [Vector3]? = nil,
    faces: [LevelFace]? = nil,
    portals: [LevelPortal]? = nil,
    flags: UInt32? = nil,
    mirrorFaceIndex: Int? = nil,
    door: RoomDoor? = nil,
    volumeLights: VolumeLightGrid? = nil,
    fog: RoomFog? = nil
) -> LevelRoom {
    LevelRoom(
        sourceIndex: sourceIndex ?? room.sourceIndex,
        name: room.name,
        pathPoint: room.pathPoint,
        vertices: vertices ?? room.vertices,
        faces: faces ?? room.faces,
        portals: portals ?? room.portals,
        flags: flags ?? room.flags,
        pulseTime: room.pulseTime,
        pulseOffset: room.pulseOffset,
        mirrorFaceIndex: mirrorFaceIndex ?? room.mirrorFaceIndex,
        door: door ?? room.door,
        volumeLights: volumeLights ?? room.volumeLights,
        fog: fog ?? room.fog,
        ambientSoundPattern: room.ambientSoundPattern,
        reverb: room.reverb,
        damage: room.damage,
        damageType: room.damageType
    )
}

private func replacing(
    _ face: LevelFace,
    corners: [FaceCorner]? = nil,
    flags: UInt16? = nil,
    texture: SourceResource? = nil,
    lightmapInfoIndex: Int? = nil,
    allowsLightCorona: Bool? = nil,
    special: SpecialFace? = nil
) -> LevelFace {
    LevelFace(
        corners: corners ?? face.corners,
        flags: flags ?? face.flags,
        portalIndex: face.portalIndex,
        texture: texture ?? face.texture,
        lightmapInfoIndex: lightmapInfoIndex ?? face.lightmapInfoIndex,
        allowsLightCorona: allowsLightCorona ?? face.allowsLightCorona,
        lightMultiple: face.lightMultiple,
        special: special ?? face.special
    )
}

private func replacing(
    _ portal: LevelPortal,
    flags: UInt32? = nil,
    pathPoint: Vector3? = nil,
    combineMaster: Int? = nil
) -> LevelPortal {
    LevelPortal(
        flags: flags ?? portal.flags,
        faceIndex: portal.faceIndex,
        connectedRoom: portal.connectedRoom,
        connectedPortal: portal.connectedPortal,
        boundaryNodeIndex: portal.boundaryNodeIndex,
        pathPoint: pathPoint ?? portal.pathPoint,
        combineMaster: combineMaster ?? portal.combineMaster
    )
}

private func replacing(_ terrain: LevelTerrain, sky: TerrainSky) -> LevelTerrain {
    LevelTerrain(
        heights: terrain.heights,
        textureCells: terrain.textureCells,
        flags: terrain.flags,
        light: terrain.light,
        red: terrain.red,
        green: terrain.green,
        blue: terrain.blue,
        dynamicLight: terrain.dynamicLight,
        occlusionChecksum: terrain.occlusionChecksum,
        occlusionMap: terrain.occlusionMap,
        sky: sky
    )
}

private func makePlacedObject(
    handle: UInt32 = 2_048,
    type: UInt8 = 6,
    storedID: Int = 0,
    definition: SourceResource? = nil,
    location: SpatialLocation = .room(2),
    position: Vector3 = .zero,
    orientation: Matrix3 = .init(
        right: .init(x: 1, y: 0, z: 0),
        up: .init(x: 0, y: 1, z: 0),
        forward: .init(x: 0, y: 0, z: 1)
    ),
    lifeLeft: Float = 0,
    soundSource: ObjectSoundSource? = nil,
    lightmapSubmodels: [ObjectLightmapSubmodel] = []
) -> PlacedObject {
    PlacedObject(
        handle: handle,
        type: type,
        storedID: storedID,
        definition: definition,
        instanceName: nil,
        flags: 0,
        doorShields: nil,
        location: location,
        position: position,
        orientation: orientation,
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: lifeLeft,
        soundSource: soundSource,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: lightmapSubmodels
    )
}

func makeMinimalCanonicalPackageLevel(
    levelKey: String = "descent3.level.training-mission"
) -> Level {
    let base = makeMinimalCanonicalLevel(levelKey: levelKey)
    let texture = base.rooms[0].faces[0].texture
    let center = RoomCamera.trainingRoom3.target
    let vertices = [
        Vector3(x: center.x + 1, y: center.y, z: center.z + 1),
        Vector3(x: center.x - 1, y: center.y, z: center.z + 1),
        Vector3(x: center.x - 1, y: center.y, z: center.z - 1),
        Vector3(x: center.x + 1, y: center.y, z: center.z - 1),
    ]
    let room = LevelRoom(
        sourceIndex: 3,
        vertices: vertices,
        faces: [
            .init(
                corners: [
                    .init(vertexIndex: 0, u: 1, v: 1, alpha: 255),
                    .init(vertexIndex: 1, u: 0, v: 1, alpha: 255),
                    .init(vertexIndex: 2, u: 0, v: 0, alpha: 255),
                    .init(vertexIndex: 3, u: 1, v: 0, alpha: 255),
                ],
                flags: 0,
                portalIndex: nil,
                texture: texture
            ),
        ],
        portals: []
    )
    let material = PresentationMaterial(
        texture: texture,
        bitmapSourceName: "wall.ogf",
        image: .init(width: 1, height: 1, rgba8: Data([255, 255, 255, 255])),
        blend: .opaque,
        lightmapBlend: .multiply,
        waterProcedural: nil,
        sourceArchive: base.source.profileFiles[0].relativePath,
        sourceSHA256: String(repeating: "d", count: 64)
    )
    let modelSource = SourceResource(storedIndex: 0, sourceName: "Synthetic.OOF")
    let shipSource = SourceResource(storedIndex: 0, sourceName: "Pyro-GL")
    let player = makePlacedObject(
        handle: 2_048,
        type: D3SourceIdentity.playerObjectType,
        storedID: 0,
        location: .room(3),
        position: RoomCamera.trainingRoom3.position,
        orientation: .init(
            right: .init(x: -1, y: 0, z: 0),
            up: RoomCamera.trainingRoom3.up,
            forward: .init(x: 0, y: 1, z: 0)
        )
    )
    let model = CanonicalModel(
        source: modelSource,
        collisionRadius: 1,
        submodels: [
            .init(
                sourceIndex: 0,
                parentIndex: nil,
                offset: .zero,
                vertices: [
                    .init(position: .zero, alpha: 1),
                    .init(position: .init(x: 1, y: 0, z: 0), alpha: 1),
                    .init(position: .init(x: 0, y: 1, z: 0), alpha: 1),
                ],
                faces: [
                    .init(
                        normal: .init(x: 0, y: 0, z: 1),
                        corners: [
                            .init(vertexIndex: 0, u: 0, v: 0),
                            .init(vertexIndex: 1, u: 1, v: 0),
                            .init(vertexIndex: 2, u: 0, v: 1),
                        ],
                        material: .texture(texture)
                    ),
                ],
                presentation: .standard
            ),
        ],
        bounds: .init(minimum: .zero, maximum: .init(x: 1, y: 1, z: 0)),
        sourceArchive: base.source.profileFiles[0].relativePath,
        sourceSHA256: String(repeating: "e", count: 64)
    )
    let ship = CanonicalShipDefinition(
        source: shipSource,
        primaryModel: modelSource,
        presentationSize: 1,
        physics: .init(
            mass: 30,
            drag: 90,
            fullThrust: 5_400,
            behaviors: [.turnroll, .wiggle, .usesThrust],
            rotationalDrag: 225,
            fullRotationalThrust: 6_860_000,
            numberOfBounces: -1,
            initialForwardVelocity: 0,
            initialAngularVelocity: .zero,
            wiggleAmplitude: 0.17,
            wigglesPerSecond: 0.9,
            coefficientOfRestitution: 1,
            hitDieDot: -1,
            maximumTurnrollRate: 8_000,
            turnrollRatio: 0.13
        )
    )
    return Level(
        missionKey: base.missionKey,
        levelKey: base.levelKey,
        source: base.source,
        metadata: base.metadata,
        rooms: base.rooms + [room],
        terrain: base.terrain,
        objects: [player],
        retiredObjectHandles: base.retiredObjectHandles,
        paths: base.paths,
        goals: base.goals,
        goalFlags: base.goalFlags,
        triggers: base.triggers,
        playerStartFlags: base.playerStartFlags,
        lightmaps: base.lightmaps,
        presentationMaterials: [material],
        models: [model],
        shipDefinitions: [ship],
        defaultPlayerBinding: .init(
            playerID: 0,
            objectHandle: player.handle,
            ship: shipSource
        ),
        objectPresentations: [
            .init(
                objectHandle: player.handle,
                primaryModel: modelSource,
                mediumModel: nil,
                lowModel: nil,
                dyingModel: nil,
                mediumDistance: nil,
                lowDistance: nil
            ),
        ],
        dependencyManifest: .init(
            current: [
                .init(
                    category: "texture",
                    source: texture,
                    state: "presentation-payload-imported",
                    provenance: "synthetic canonical fixture"
                ),
                .init(
                    category: "model",
                    source: modelSource,
                    state: "presentation-payload-imported",
                    provenance: "synthetic canonical fixture"
                ),
                .init(
                    category: "ship-definition",
                    source: shipSource,
                    state: "canonical-typed-definition",
                    provenance: "synthetic canonical fixture"
                ),
            ],
            historicalEagerBaseline: nil
        ),
        sourceChunks: base.sourceChunks
    )
}

func makeMinimalCanonicalLevel(levelKey: String = "descent3.level.training-mission") -> Level {
    let corners = [
        FaceCorner(vertexIndex: 0, u: 0, v: 0, alpha: 255),
        FaceCorner(vertexIndex: 1, u: 1, v: 0, alpha: 255),
        FaceCorner(vertexIndex: 2, u: 0, v: 1, alpha: 255),
    ]
    let texture = SourceResource(storedIndex: 0, sourceName: "wall")
    let room2 = LevelRoom(
        sourceIndex: 2,
        vertices: [.zero, .init(x: 1, y: 0, z: 0), .init(x: 0, y: 1, z: 0)],
        faces: [.init(corners: corners, flags: 0, portalIndex: 0, texture: texture)],
        portals: [.init(faceIndex: 0, connectedRoom: 4, connectedPortal: 0)]
    )
    let room4 = LevelRoom(
        sourceIndex: 4,
        vertices: [.zero, .init(x: 1, y: 0, z: 0), .init(x: 0, y: 1, z: 0)],
        faces: [.init(corners: Array(corners.reversed()), flags: 0, portalIndex: 0, texture: texture)],
        portals: [.init(faceIndex: 0, connectedRoom: 2, connectedPortal: 0)]
    )
    return Level(
        missionKey: "descent3.mission.pilot-training",
        levelKey: levelKey,
        source: .init(
            profileIdentifier: "test",
            profileFiles: [
                .init(
                    relativePath: "missions/training.mn3",
                    byteCount: 1,
                    sha256: canonicalSHA256(Data("x".utf8))
                ),
            ],
            archiveSHA256: String(repeating: "a", count: 64),
            levelSHA256: String(repeating: "b", count: 64),
            d3lvVersion: 127
        ),
        metadata: LevelMetadata(
            name: "",
            designer: "",
            copyright: "",
            notes: "",
            gravity: 0,
            alwaysCheckCeiling: false,
            ceilingHeight: 0
        ),
        rooms: [room2, room4],
        terrain: makeTestLevelTerrain(),
        objects: [],
        paths: [],
        goals: [],
        triggers: [],
        playerStartFlags: [],
        lightmaps: LightmapCatalog(pages: [], infos: []),
        dependencyManifest: .init(
            current: [
                .init(
                    category: "texture",
                    source: texture,
                    state: "identity-recorded",
                    provenance: "synthetic canonical fixture"
                ),
            ],
            historicalEagerBaseline: nil
        ),
        sourceChunks: [
            .init(
                name: "TEST",
                byteCount: 0,
                sha256: String(repeating: "c", count: 64),
                disposition: "synthetic-test-fixture"
            ),
        ]
    )
}

private func removingDefaultPlayerPresentation(from level: Level) -> Level {
    Level(
        schemaVersion: level.schemaVersion,
        missionKey: level.missionKey,
        levelKey: level.levelKey,
        source: level.source,
        metadata: level.metadata,
        rooms: level.rooms,
        terrain: level.terrain,
        objects: [],
        retiredObjectHandles: level.retiredObjectHandles,
        paths: level.paths,
        goals: level.goals,
        goalFlags: level.goalFlags,
        triggers: level.triggers,
        playerStartFlags: level.playerStartFlags,
        lightmaps: level.lightmaps,
        surfacePhysics: level.surfacePhysics,
        presentationMaterials: level.presentationMaterials,
        presentationCoronaAssets: level.presentationCoronaAssets,
        models: [],
        shipDefinitions: [],
        defaultPlayerBinding: nil,
        objectPresentations: [],
        dependencyManifest: .init(
            current: level.dependencyManifest.current.filter { $0.category == "texture" },
            historicalEagerBaseline: level.dependencyManifest.historicalEagerBaseline
        ),
        sourceChunks: level.sourceChunks
    )
}

private func makeTestLevelTerrain() -> LevelTerrain {
    LevelTerrain(
        heights: [UInt8](repeating: 0, count: 65_536),
        textureCells: [TerrainTextureCell](
            repeating: .init(
                texture: .init(storedIndex: 0, sourceName: "wall"),
                rotationAndTile: 0
            ),
            count: 1_024
        ),
        flags: [UInt8](repeating: 0, count: 65_536),
        light: [UInt8](repeating: 0, count: 65_536),
        red: [UInt8](repeating: 0, count: 65_536),
        green: [UInt8](repeating: 0, count: 65_536),
        blue: [UInt8](repeating: 0, count: 65_536),
        dynamicLight: [UInt8](repeating: 0, count: 65_536),
        occlusionChecksum: 0,
        occlusionMap: [UInt8](repeating: 0, count: 8_192),
        sky: nil
    )
}
