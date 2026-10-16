import XCTest

// The canonical package boundary (CanonicalPackage.swift): the writer and
// loader, the content manifest, the native package library's install,
// promotion, and recovery, and the request queue.
final class CanonicalPackageTests: XCTestCase {
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

    func testPackageBoundaryRefusesSchemasBeforeFourteen() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(path: "library", directoryHint: .isDirectory)
        )
        func isInvalidIdentity(_ error: Error) -> Bool {
            error as? LevelValidationError == .invalidIdentity
        }

        let current = makeMinimalCanonicalPackageLevel()
        XCTAssertEqual(current.schemaVersion, Level.scriptedSchemaVersion)
        let scriptFree = replacing(current, schemaVersion: 11, soundClips: [])
        XCTAssertNoThrow(try scriptFree.validate())
        let refusedWrite = root.appending(path: "refused.revival", directoryHint: .isDirectory)
        XCTAssertThrowsError(try writeCanonicalPackage(scriptFree, to: refusedWrite)) {
            XCTAssertTrue(isInvalidIdentity($0))
        }

        let package = root.appending(path: "released.revival", directoryHint: .isDirectory)
        try writeCanonicalPackage(current, to: package)
        XCTAssertEqual(try loadCanonicalLevel(from: package), current)
        try overwriteCanonicalPackageLevel(scriptFree, at: package)
        XCTAssertThrowsError(try loadCanonicalLevel(from: package)) {
            XCTAssertTrue(isInvalidIdentity($0))
        }
        XCTAssertThrowsError(try library.installAndActivate(from: package)) {
            XCTAssertTrue(isInvalidIdentity($0))
        }
        for oldSchema in [12, 13] {
            var levelObject = try XCTUnwrap(
                JSONSerialization.jsonObject(with: canonicalJSONData(current))
                    as? [String: Any]
            )
            levelObject["schemaVersion"] = oldSchema
            try overwriteCanonicalPackageLevelData(
                JSONSerialization.data(withJSONObject: levelObject, options: [.sortedKeys]),
                identity: current,
                at: package
            )
            XCTAssertThrowsError(try loadCanonicalLevel(from: package)) {
                XCTAssertTrue(isInvalidIdentity($0))
            }
            XCTAssertThrowsError(try library.installAndActivate(from: package)) {
                XCTAssertTrue(isInvalidIdentity($0))
            }
        }
    }

    func testPackageRequiresShipArmorAndLoadedDamageUsesItsValue() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        var level = makeMinimalCanonicalPackageLevel()
        level.shipDefinitions[0].armorScalar = 2
        try writeCanonicalPackage(level, to: root)
        let loaded = try loadCanonicalLevel(from: root)
        XCTAssertEqual(loaded.shipDefinitions[0].armorScalar, 2)
        var world = GameWorld(level: loaded)
        world.makePlayerVulnerable()
        XCTAssertTrue(world.applyDamageToPlayer(
            world.testPlayerObject.handle, damage: 60, level: loaded
        ))
        XCTAssertEqual(world.shields, -20)
        XCTAssertNotNil(world.playerDeath)

        var encoded = try XCTUnwrap(
            JSONSerialization.jsonObject(with: canonicalJSONData(level))
                as? [String: Any]
        )
        var ships = try XCTUnwrap(encoded["shipDefinitions"] as? [[String: Any]])
        ships[0].removeValue(forKey: "armorScalar")
        encoded["shipDefinitions"] = ships
        try overwriteCanonicalPackageLevelData(
            JSONSerialization.data(withJSONObject: encoded, options: [.sortedKeys]),
            identity: level, at: root
        )
        XCTAssertThrowsError(try loadCanonicalLevel(from: root)) {
            guard case let DecodingError.keyNotFound(key, _) = $0 else {
                return XCTFail("Expected missing armorScalar, got \($0)")
            }
            XCTAssertEqual(key.stringValue, "armorScalar")
        }
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
            at: invalidCandidate, withIntermediateDirectories: false
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
            path: "unbound.revival", directoryHint: .isDirectory
        )
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(path: "library", directoryHint: .isDirectory)
        )
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let bound = packageLevel(makeSliceSixObjectRenderLevel())
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
            path: "successor.revival", directoryHint: .isDirectory
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
            at: destination, withDestinationURL: missingTarget
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
            path: ".candidate-abandoned.revival", directoryHint: .isDirectory
        )
        let unrelated = packages.appending(
            path: ".unrelated.revival", directoryHint: .isDirectory
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
            withJSONObject: manifestObject, options: [.prettyPrinted]
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
        let topologyOnly = packageLevel(makeMinimalCanonicalLevel())
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
        let topologyOnly = packageLevel(makeMinimalCanonicalLevel())
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
            CanonicalPackageManifest.self, from: Data(contentsOf: manifestURL)
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

    func testPackageLevelWithoutItsSoundClipTableIsRefused() throws {
        let level = makeMinimalCanonicalPackageLevel()
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
        try overwriteCanonicalPackageLevelData(
            JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
            identity: level,
            at: package
        )
        XCTAssertThrowsError(try loadCanonicalLevel(from: package)) {
            XCTAssertEqual($0 as? LevelValidationError, .invalidIdentity)
        }
    }

    func testCanonicalLoaderRejectsOverflowingPCMMetadata() throws {
        let base = makeMinimalCanonicalPackageLevel()
        let archive = try XCTUnwrap(
            base.source.profileFiles.first?.relativePath
        )
        let voice = CanonicalVoiceClip(
            sourceName: "overflow.osf", sourceEntryIndex: 999,
            sampleRate: 22_050, channelCount: 1, frameCount: Int.max / 2 + 1,
            pcm16LittleEndian: Data([0, 0]),
            pcmSHA256: canonicalSHA256(Data([0, 0])), sourceArchive: archive,
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
            archiveEntryName: "training.d3l", archiveEntryOffset: 32,
            archiveEntryByteCount: 64,
            referenceChecksum: String(repeating: "c", count: 32),
            referenceChecksumBasis: "pinned-source-provenance-implied-by-exact-level-sha256"
        )
        let dependency = DependencyRecord(
            category: "texture",
            source: .init(storedIndex: 0, sourceName: "wall"),
            state: "presentation-payload-imported", provenance: "TXNM"
        )
        let chunk = SourceChunkRecord(
            name: "ROOM", byteCount: 1,
            sha256: String(repeating: "a", count: 64),
            disposition: "canonical-topology"
        )
        let dependencies = base.dependencyManifest.current.map {
            $0.category == dependency.category && $0.source == dependency.source
                ? dependency
                : $0
        }

        let level = replacing(
            base, source: source,
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
            "behavior-execution", "matcen-production",
            "volumetric-navigation-rebuild",
        ])
        XCTAssertEqual(manifest.source, source)
        XCTAssertEqual(manifest.sourceEntries, [chunk])
        XCTAssertEqual(manifest.currentDependencies, level.dependencyManifest.current)
        XCTAssertTrue(manifest.currentDependencies.contains(dependency))
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
        let validLevel = replacing(base, objects: [firstPlayer, secondPlayer])
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
                at: temporaryDirectory, withIntermediateDirectories: false
            )
            try writeCanonicalPackage(validLevel, to: package)
            try overwriteCanonicalPackageLevel(
                replacing(validLevel, objects: objects), at: package
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
                error as? LevelValidationError, .invalidFace(room: 3, face: 0)
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
                    width: 128, height: 128,
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
                            kind: .heightBlob, frequency: 20, speed: 40,
                            size: size, x1: x1, y1: y1, x2: 0, y2: 0
                        ),
                    ]
                ),
                sourceArchive: sourceMaterial.sourceArchive,
                sourceSHA256: sourceMaterial.sourceSHA256
            )
        }

        let valid = replacing(
            base, presentationMaterials: [waterMaterial(x1: 127, y1: 127)]
        )
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let package = root.appending(path: "hostile.revival", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try writeCanonicalPackage(valid, to: package)
        let cases: [(x1: UInt8, y1: UInt8, size: UInt8, writes: Bool)] = [
            (128, 64, 1, false), (129, 64, 1, false), (64, 128, 1, false),
            (64, 129, 1, false), (.max, 64, 1, false), (128, 64, 3, true),
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
                image: material.image, definition: definition
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
                    evaluated, unchanged,
                    "Expected source-clipped overlap for center (\(x1), \(y1)), size \(size)"
                )
            } else {
                XCTAssertEqual(
                    evaluated, unchanged,
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
            path: "successor.revival", directoryHint: .isDirectory
        )
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(path: "library", directoryHint: .isDirectory)
        )
        let priorLevel = packageLevel(makeSliceSixObjectRenderLevel())
        let validSuccessor = priorLevel
        let playerView = defaultPlayerView(in: validSuccessor)
        let referencePlayerView = PlayerView(
            playerID: playerView.playerID,
            objectHandle: playerView.objectHandle, roomSourceIndex: 3,
            camera: .trainingRoom3, collisionRadius: playerView.collisionRadius
        )
        let visibleFace = try XCTUnwrap(
            try extractWorldForRendering(
                validSuccessor, playerView: referencePlayerView
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
                assetIndex: 0, tint: .init(x: 1, y: 1, z: 1),
                blend: .additiveSourceAlpha(opacity: 102)
            ),
            sourceArchive: material.sourceArchive,
            sourceSHA256: material.sourceSHA256
        )
        let coronaAsset = PresentationCoronaAsset(
            source: coronaSource, bitmapSourceName: "hostile-flare.ogf",
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
                        category: "presentation-effect", source: coronaSource,
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
            archiveEntryName: "training.d3l", archiveEntryOffset: 32,
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
                at: temporaryDirectory, withIntermediateDirectories: false
            )
            try writeCanonicalPackage(validLevel, to: package)
            try overwriteCanonicalPackageLevel(
                replacing(validLevel, source: invalidSource), at: package
            )

            XCTAssertThrowsError(try loadCanonicalLevel(from: package)) { error in
                XCTAssertEqual(error as? LevelValidationError, .invalidIdentity)
            }
        }
    }
}
