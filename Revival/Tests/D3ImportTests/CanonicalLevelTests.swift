import XCTest

final class CanonicalLevelTests: XCTestCase {
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

func assertValidationError(
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
    trainingDodgeAttempt: TrainingDodgeAttempt? = nil,
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
    trainingFinalGoalChain: TrainingFinalGoalChain? = nil,
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
        trainingDodgeAttempt:
            trainingDodgeAttempt ?? level.trainingDodgeAttempt,
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
        trainingFinalGoalChain:
            trainingFinalGoalChain
            ?? level.trainingFinalGoalChain,
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
    replaced.trainingFinalGoalChain =
        trainingFinalGoalChain ?? level.trainingFinalGoalChain
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
