import XCTest

// Level.validate (Level.swift), the one structural check of a level at
// import, package load, and authoring: the source identity, the legacy
// table ceilings, rooms, faces, portals, lightmaps, objects, goals,
// triggers, the object tables, and the dependency closure.
final class LevelValidationTests: XCTestCase {
    /// The fixtures the other tests build on keep their stock values: the
    /// maneuver level's paths and FollowBot1's page (the retail RAS1 flyer),
    /// and the minimal level's sparse room numbers.
    func testModelBatteryCanReferenceATurretWithRotationDisabled() throws {
        var level = makeSliceSixObjectRenderLevel()
        level.models[4].weaponBatteries = [.init(gunpoints: [], turrets: [0])]
        XCTAssertNoThrow(try level.validate())
        level.models[4].weaponBatteries = [.init(gunpoints: [], turrets: [99])]
        XCTAssertThrowsError(try level.validate()) {
            XCTAssertEqual($0 as? LevelValidationError,
                           .invalidObjectTables("model guns invisiblepowerup.OOF"))
        }
    }

    func testFixturesKeepTheirStockPathsFlyerAIAndSparseRooms() throws {
        let level = makeTrainingManeuverFollowLevel()
        XCTAssertEqual(level.paths.map(\.name), ["FollowLoop1", "GoToDie"])
        XCTAssertEqual(level.paths.map(\.nodes.count), [13, 1])
        let bot = try XCTUnwrap(level.objects.first { $0.handle == 8_200 })
        XCTAssertEqual(bot.flags, 5_121)
        XCTAssertEqual(bot.location, .room(37))
        let ai = try XCTUnwrap(
            level.objectInfo(for: ObjectHandle(bot.handle))?.ai
        )
        XCTAssertEqual(ai.maxVelocity, 40)
        XCTAssertEqual(ai.maxDeltaVelocity, 80)
        XCTAssertEqual(ai.maxTurnRate, 12_000)
        XCTAssertEqual(ai.maxDeltaTurnRate, 16_000)
        XCTAssertEqual(ai.circleDistance, 25)
        XCTAssertNoThrow(try level.validate())

        let minimal = makeMinimalCanonicalLevel()
        XCTAssertNoThrow(try minimal.validate())
        XCTAssertEqual(minimal.rooms.map(\.sourceIndex), [2, 4])
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
            .invalidSurfacePhysics, replacing(base, surfacePhysics: [])
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
            handle: 2_048, type: D3SourceIdentity.playerObjectType, storedID: 0,
            location: .room(3)
        )
        let presentation = ObjectPresentationReference.fixture(
            player.handle, modelSource
        )
        let dependency = DependencyRecord(
            category: "model", source: modelSource,
            state: "presentation-payload-imported",
            provenance: "synthetic canonical fixture"
        )
        let shipSource = SourceResource(storedIndex: 0, sourceName: "Pyro-GL")
        let ship = CanonicalShipDefinition(
            source: shipSource,
            primaryModel: modelSource,
            presentationSize: 1,
            physics: .init(
                mass: 30, drag: 90, fullThrust: 5_400,
                behaviors: [.turnroll, .wiggle, .usesThrust],
                rotationalDrag: 225, fullRotationalThrust: 6_860_000,
                numberOfBounces: -1, initialForwardVelocity: 0,
                initialAngularVelocity: .zero, wiggleAmplitude: 0.17,
                wigglesPerSecond: 0.9, coefficientOfRestitution: 1,
                hitDieDot: -1, maximumTurnrollRate: 8_000, turnrollRatio: 0.13
            )
        )
        let binding = DefaultPlayerBinding(
            playerID: 0, objectHandle: player.handle, ship: shipSource
        )
        let shipDependency = DependencyRecord(
            category: "ship-definition", source: shipSource,
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
            .invalidDependency("missing texture:model-surface"), incomplete
        )

        let modelMaterial = PresentationMaterial(
            texture: missingTexture, bitmapSourceName: "model-surface.ogf",
            image: .init(width: 1, height: 1, rgba8: Data([255, 255, 255, 255])),
            blend: .opaque, lightmapBlend: .none, waterProcedural: nil,
            sourceArchive: base.source.profileFiles[0].relativePath,
            sourceSHA256: String(repeating: "f", count: 64)
        )
        let textureDependency = DependencyRecord(
            category: "texture", source: missingTexture,
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
                    dependency, shipDependency, textureDependency,
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

    /// A valid level with a presented object but no default player binding
    /// prepares its draws from the placed objects; only a level with a
    /// player start runs level start for them (GameWorld.init needs the
    /// player).
    func testPreparedModelDrawsWithoutAPlayerBindingUseThePlacedObjects() throws {
        let packaged = makeMinimalCanonicalPackageLevel()
        let level = packageLevel(Level(
            schemaVersion: packaged.schemaVersion,
            missionKey: packaged.missionKey,
            levelKey: packaged.levelKey,
            source: packaged.source,
            metadata: packaged.metadata,
            rooms: packaged.rooms,
            terrain: packaged.terrain,
            objects: packaged.objects,
            retiredObjectHandles: packaged.retiredObjectHandles,
            paths: packaged.paths,
            goals: packaged.goals,
            goalFlags: packaged.goalFlags,
            triggers: packaged.triggers,
            playerStartFlags: packaged.playerStartFlags,
            lightmaps: packaged.lightmaps,
            surfacePhysics: packaged.surfacePhysics,
            presentationMaterials: packaged.presentationMaterials,
            models: packaged.models,
            objectPresentations: packaged.objectPresentations,
            dependencyManifest: .init(
                current: packaged.dependencyManifest.current.filter {
                    $0.category != "ship-definition"
                },
                historicalEagerBaseline: nil
            ),
            sourceChunks: packaged.sourceChunks
        ))
        XCTAssertNil(level.defaultPlayerBinding)
        XCTAssertFalse(level.objectPresentations.isEmpty)
        try level.validate()

        let items = extractPreparedModelDrawItems(level)
        XCTAssertEqual(
            Set(items.map(\.objectHandle)),
            Set(level.objectPresentations.map(\.objectHandle))
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
        objects[playerIndex] = PlacedObject.fixture(
            handle: player.handle, type: player.type, storedID: player.storedID,
            definition: player.definition, name: player.instanceName,
            flags: player.flags, doorShields: player.doorShields,
            location: .terrainCell(0), position: player.position,
            orientation: player.orientation, containsType: player.containsType,
            containsID: player.containsID, containsCount: player.containsCount,
            lifeLeft: player.lifeLeft, soundSource: player.soundSource,
            inertScriptName: player.inertScriptName,
            inertModuleName: player.inertModuleName,
            lightmapSubmodels: player.lightmapSubmodels
        )

        assertValidationError(
            .invalidDependency("default player ship binding"),
            replacing(base, objects: objects)
        )
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
                corners: firstFace.corners, flags: firstFace.flags,
                portalIndex: 1, texture: firstFace.texture
            )
            let firstPortal = room.portals[0]
            let master = replacing(firstPortal, flags: 0x0000_0008, combineMaster: 0)
            let member = LevelPortal(
                flags: 0x0000_0009, faceIndex: 1,
                connectedRoom: firstPortal.connectedRoom, connectedPortal: 1,
                boundaryNodeIndex: firstPortal.boundaryNodeIndex,
                pathPoint: firstPortal.pathPoint, combineMaster: 0
            )
            return replacing(
                room, faces: [firstFace, secondFace], portals: [master, member]
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
            pageIndex: 0, width: 2, height: 2, type: 0, x: 3, y: 3, xSpacing: 0,
            ySpacing: 0, upperLeft: .zero, normal: .zero
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
                            lightmapInfoIndex: 0, right: .zero, up: .zero,
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
                type: 0, points: [], smoothedVertexNormals: [.zero, .zero]
            )
        )
        let specialRoom = replacing(level.rooms[0], faces: [invalidSpecialFace])
        assertValidationError(
            .invalidSpecialFace(room: level.rooms[0].sourceIndex, face: 0),
            replacing(level, rooms: [specialRoom, level.rooms[1]])
        )

        let trigger = LevelTrigger(
            name: "missing-face-flag", roomIndex: level.rooms[0].sourceIndex,
            faceIndex: 0, flags: 0, activator: 0
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
                vertexIndex: $0.vertexIndex, u: $0.u, v: $0.v, alpha: $0.alpha,
                lightmapU: 0, lightmapV: 0
            )
        }

        let unflaggedWithLightmap = replacing(
            face, corners: litCorners, lightmapInfoIndex: 0
        )
        let lightmaps = LightmapCatalog(
            pages: [.init(width: 4, height: 4)],
            infos: [
                .init(
                    pageIndex: 0, width: 2, height: 2, type: 0, x: 0, y: 0,
                    xSpacing: 0, ySpacing: 0, upperLeft: .zero, normal: .zero
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
            vertexIndex: partialCorners[0].vertexIndex, u: partialCorners[0].u,
            v: partialCorners[0].v, alpha: partialCorners[0].alpha,
            lightmapU: 0, lightmapV: nil
        )
        let partialLightmap = replacing(
            face, corners: partialCorners, flags: face.flags | 0x0001,
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
                level, rooms: [externalRoom, level.rooms[1]],
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
                category: value.category, source: value.source,
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
            mass: physics.mass, drag: 0, fullThrust: physics.fullThrust,
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
                        source: ship.source, primaryModel: ship.primaryModel,
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
                        type: type, sourceHandle: sourceObject.handle,
                        objectHandle: objectHandle, done: false
                    ),
                ]
            )
        }

        assertValidationError(
            .invalidGoalObject(sourceObject.handle),
            replacing(
                level, objects: [sourceObject, otherObject],
                goals: [goal(objectHandle: nil)]
            )
        )
        assertValidationError(
            .invalidGoalObject(sourceObject.handle),
            replacing(
                level, objects: [sourceObject, otherObject],
                goals: [goal(objectHandle: otherObject.handle)]
            )
        )
        assertValidationError(
            .invalidGoalObject(sourceObject.handle),
            replacing(
                level, objects: [sourceObject, otherObject],
                goals: [goal(type: 0, objectHandle: sourceObject.handle)]
            )
        )
    }

    func testRetainsEveryStoredObjectIDAndOnlyAttachesDefinitionBearingTypes() throws {
        let level = makeMinimalCanonicalLevel()
        let viewer = makePlacedObject(type: 6, storedID: 20)
        let genericDefinition = SourceResource(storedIndex: 4, sourceName: "robot")
        let generic = makePlacedObject(
            handle: 2_049, type: 2, storedID: 4, definition: genericDefinition
        )
        let valid = replacing(
            level,
            objects: [viewer, generic],
            dependencyManifest: .init(
                current: level.dependencyManifest.current + [
                    .init(
                        category: "object-definition",
                        source: genericDefinition, state: "identity-recorded",
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
            storedIndex: 20, sourceName: "fabricated-viewer-name"
        )
        assertValidationError(
            .invalidObjectDefinition(2_048),
            replacing(
                level,
                objects: [
                    makePlacedObject(
                        type: 6, storedID: 20, definition: fabricatedDefinition
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
            name: "ROOM", byteCount: 1, sha256: validHash,
            disposition: "canonical-topology"
        )
        assertValidationError(.invalidSourceChunk("missing"), replacing(level, sourceChunks: []))
        let malformedChunks = [
            SourceChunkRecord(
                name: "", byteCount: 1, sha256: validHash,
                disposition: "canonical-topology"
            ),
            SourceChunkRecord(
                name: "ROOM", byteCount: -1, sha256: validHash,
                disposition: "canonical-topology"
            ),
            SourceChunkRecord(
                name: "ROOM", byteCount: 1, sha256: "bad",
                disposition: "canonical-topology"
            ),
            SourceChunkRecord(
                name: "ROOM", byteCount: 1, sha256: validHash, disposition: ""
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
            state: "identity-recorded", provenance: "TXNM"
        )
        let malformedDependency = DependencyRecord(
            category: extraDependency.category, source: extraDependency.source,
            state: "", provenance: extraDependency.provenance
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
                        extraDependency, extraDependency,
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
                            state: "identity-recorded", provenance: "TXNM"
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
                profileFiles: [duplicateFingerprint, duplicateFingerprint]
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
                        byteCount: -1, sha256: duplicateFingerprint.sha256
                    ),
                ]
            ),
            replacing(
                source,
                profileFiles: [
                    .init(
                        relativePath: duplicateFingerprint.relativePath,
                        byteCount: duplicateFingerprint.byteCount, sha256: "bad"
                    ),
                ]
            ),
            replacing(source, archiveSHA256: "bad"),
            replacing(source, levelSHA256: "bad"),
            replacing(
                source, referenceChecksum: "not-a-32-character-lowercase-hash",
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
                        faces: [], portals: []
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
            corners: corners, flags: 0, portalIndex: nil,
            texture: .init(storedIndex: 0, sourceName: "wall")
        )
        assertValidationError(
            .invalidCount("room 0"),
            replacing(
                level,
                rooms: [
                    LevelRoom(
                        sourceIndex: 0, vertices: [.zero, .zero, .zero],
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
            position: .zero, location: .room(level.rooms[0].sourceIndex),
            flags: 0, forward: .zero, up: .zero
        )
        assertValidationError(
            .invalidCount("path nodes"),
            replacing(
                level,
                paths: [.init(name: "path", flags: 0, nodes: [GamePathNode](repeating: pathNode, count: 101))]
            )
        )
        let goal = LevelGoal(
            status: 0, priority: 0, list: 0, name: "goal", itemName: "",
            description: "", completionMessage: "", items: []
        )
        assertValidationError(
            .invalidCount("goals"),
            replacing(level, goals: [LevelGoal](repeating: goal, count: 33))
        )
        let goalObject = makePlacedObject()
        let goalItem = LevelGoalItem(
            type: 2, sourceHandle: goalObject.handle,
            objectHandle: goalObject.handle, done: false
        )
        assertValidationError(
            .invalidCount("goal items"),
            replacing(
                level,
                objects: [goalObject],
                goals: [
                    .init(
                        status: 0, priority: 0, list: 0, name: "goal",
                        itemName: "", description: "", completionMessage: "",
                        items: [LevelGoalItem](repeating: goalItem, count: 13)
                    ),
                ]
            )
        )
        let satellite = TerrainSatellite(
            texture: .init(storedIndex: 0, sourceName: "wall"), vector: .zero,
            flags: 0, size: 0, red: 0, green: 0, blue: 0
        )
        let sky = TerrainSky(
            fogScalar: 0, damagePerSecond: 0, textured: false,
            domeTexture: .init(storedIndex: 0, sourceName: "wall"), skyColor: 0,
            horizonColor: 0, fogColor: 0, flags: 0, radius: 0, rotationRate: 0,
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
                        repeating: .init(width: 1, height: 1), count: 65_535
                    ),
                    infos: []
                )
            )
        )

        var sourceMaximumPages = [LightmapPageMetadata](
            repeating: .init(width: 1, height: 1), count: 65_534
        )
        sourceMaximumPages[0] = .init(width: 129, height: 1)
        assertValidationError(
            .invalidLightmapPage(0),
            replacing(
                level, lightmaps: .init(pages: sourceMaximumPages, infos: [])
            )
        )

        let info = LightmapInfoRecord(
            pageIndex: 0, width: 2, height: 2, type: 0, x: 0, y: 0, xSpacing: 0,
            ySpacing: 0, upperLeft: .zero, normal: .zero
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
            pageIndex: 0, width: 1, height: 2, type: 0, x: 0, y: 0, xSpacing: 0,
            ySpacing: 0, upperLeft: .zero, normal: .zero
        )
        assertValidationError(
            .invalidLightmapInfo(0),
            replacing(
                level,
                lightmaps: .init(
                    pages: [.init(width: 4, height: 4)], infos: [undersizedInfo]
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
            name: "source-trigger", roomIndex: triggerRoom.sourceIndex,
            faceIndex: 0, flags: 0, activator: 0
        )

        assertValidationError(
            .invalidCount("triggers"),
            replacing(
                level, rooms: rooms,
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
                    pageIndex: 0, width: 2, height: 2, type: 0, x: 0, y: 0,
                    xSpacing: 0, ySpacing: 0, upperLeft: .zero, normal: .zero
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
                    state: "identity-recorded", provenance: "NLMP metadata"
                ),
                .init(
                    category: "object-definition", source: definition,
                    state: "identity-recorded", provenance: "OBJS placed object"
                ),
            ],
            historicalEagerBaseline: nil
        )
        XCTAssertNoThrow(
            try replacing(
                level, objects: [object], lightmaps: lightmaps,
                dependencyManifest: completeDependencies
            ).validate()
        )
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
                Level.self, from: JSONSerialization.data(withJSONObject: object)
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
            .invalidObjectTables("model guns \(turretModel.source.sourceName)"),
            try hostile { object in
                var models = try XCTUnwrap(object["models"] as? [[String: Any]])
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
            sampleRate: clip.sampleRate, channelCount: clip.channelCount,
            frameCount: clip.frameCount, pcm16LittleEndian: Data([1, 0]),
            pcmSHA256: clip.pcmSHA256, sourceArchive: clip.sourceArchive,
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

    func testCanonicalTextureAnimationFramesMayShareSourcePageIndex() {
        XCTAssertTrue(
            allowsDuplicateDependencyStoredIndex(
                category: "texture", sourceName: "yellowspark.oaf frame 1"
            )
        )
        XCTAssertFalse(
            allowsDuplicateDependencyStoredIndex(
                category: "texture", sourceName: "FlarePuff"
            )
        )
        XCTAssertFalse(
            allowsDuplicateDependencyStoredIndex(
                category: "sound", sourceName: "yellowspark.oaf frame 1"
            )
        )
    }

    /// A weapon's explosion frames join the dependency manifest as
    /// imported textures, each once.
    func testWeaponExplosionFramesAreMarkedImported() {
        let explosionFrames = [
            .init(storedIndex: 398, sourceName: "ExplosionE"),
        ] + (1..<15).map {
            SourceResource(
                storedIndex: 398, sourceName: "ExplosionE.oaf frame \($0)"
            )
        }

        let updated = makeMinimalCanonicalLevel()
            .appendingTextureDependencies(
                explosionFrames + explosionFrames,
                provenance: "synthetic weapon page"
            )
        let importedExplosionFrames = updated.dependencyManifest.current
            .filter {
                $0.category == "texture"
                    && $0.source.sourceName.hasPrefix("ExplosionE")
            }
        XCTAssertEqual(importedExplosionFrames.map(\.source), explosionFrames)
        XCTAssertTrue(
            importedExplosionFrames.allSatisfy {
                $0.state == "presentation-payload-imported"
            }
        )
    }

    func testCanonicalWeaponDefinitionSourceIdentityAcceptsStockIndex() {
        XCTAssertTrue(
            D3SourceIdentity.isValidSourceResource(
                .init(storedIndex: 3, sourceName: "Yellow flare"),
                category: "weapon-definition"
            )
        )
    }
}
