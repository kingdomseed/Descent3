import Darwin
import XCTest

final class D3ImportOperationTests: XCTestCase {
    func testParsesReachedShipPhysicsInReleasedFieldOrderAndTypesFlags() throws {
        let pages = try resolveReachedObjectModelPages(
            table: makeRetailShipTablePage() + makeRetailGenericModelTablePage(),
            overlay: Data(),
            shipName: "Pyro-GL",
            genericName: "Invisiblepowerup"
        )
        let definition = try XCTUnwrap(pages.ship.shipDefinition)

        XCTAssertEqual(definition.name, "Pyro-GL")
        XCTAssertEqual(definition.presentationSize, 6.676084041595459)
        XCTAssertEqual(definition.physics.mass, 30)
        XCTAssertEqual(definition.physics.drag, 90)
        XCTAssertEqual(definition.physics.fullThrust, 5_400)
        XCTAssertEqual(
            definition.physics.behaviors,
            [.turnroll, .wiggle, .usesThrust]
        )
        XCTAssertEqual(definition.physics.rotationalDrag, 225)
        XCTAssertEqual(definition.physics.fullRotationalThrust, 6_860_000)
        XCTAssertEqual(definition.physics.numberOfBounces, -1)
        XCTAssertEqual(definition.physics.initialForwardVelocity, 0)
        XCTAssertEqual(definition.physics.initialAngularVelocity, .zero)
        XCTAssertEqual(definition.physics.wiggleAmplitude, 0.17)
        XCTAssertEqual(definition.physics.wigglesPerSecond, 0.9)
        XCTAssertEqual(definition.physics.coefficientOfRestitution, 1)
        XCTAssertEqual(definition.physics.hitDieDot, -1)
        XCTAssertEqual(definition.physics.maximumTurnrollRate, 8_000)
        XCTAssertEqual(definition.physics.turnrollRatio, 0.13)
    }

    func testReachedOOFPreservesCustomFacingAndRotationAndRejectsUnreachedPresentationProperties() throws {
        let texture = SourceResource(storedIndex: 0, sourceName: "Synthetic")
        let custom = try parseReachedOutrageModel(
            makeReachedOOFFixture(properties: "$custom"),
            sourceName: "Synthetic.OOF",
            sourceArchive: "d3.hog",
            textureResources: [texture]
        )

        XCTAssertEqual(custom.submodels[1].presentation, .custom)
        let facing = try parseReachedOutrageModel(
            makeReachedOOFFixture(properties: "$facing"),
            sourceName: "Synthetic.OOF",
            sourceArchive: "d3.hog",
            textureResources: [texture]
        )
        XCTAssertEqual(facing.submodels[1].presentation, .facing)
        let rotating = try parseReachedOutrageModel(
            makeReachedOOFFixture(properties: "$rotate=1"),
            sourceName: "Synthetic.OOF",
            sourceArchive: "d3.hog",
            textureResources: [texture]
        )
        XCTAssertEqual(
            rotating.submodels[1].presentation,
            .rotate(rate: 1, axis: .init(x: 0, y: 1, z: 0))
        )
        for properties in ["$thruster=1, 0.5, 0.25, 2"] {
            XCTAssertThrowsError(
                try parseReachedOutrageModel(
                    makeReachedOOFFixture(properties: properties),
                    sourceName: "Synthetic.OOF",
                    sourceArchive: "d3.hog",
                    textureResources: [texture]
                )
            ) {
                XCTAssertEqual(
                    $0 as? OutrageModelImportError,
                    .unsupportedPresentation(properties)
                )
            }
        }
    }

    func testReachedOOFUsesFirstActualTransformedVertexAndDynamicGlowGeometry() throws {
        let sourceRadius = Float(bitPattern: 0x40d9_5869)
        let data = makeReachedOOFFixture(collisionRadius: sourceRadius)

        let model = try parseReachedOutrageModel(
            data,
            sourceName: "Synthetic.OOF",
            sourceArchive: "d3.hog",
            textureResources: [.init(storedIndex: 0, sourceName: "Synthetic")]
        )

        XCTAssertEqual(model.bounds.minimum.x, 104.00513, accuracy: 0.0001)
        XCTAssertEqual(model.bounds.maximum.x, 106, accuracy: 0.0001)
        XCTAssertEqual(model.bounds.minimum.y, -0.9987165, accuracy: 0.0001)
        XCTAssertEqual(model.bounds.maximum.y, 0.9987165, accuracy: 0.0001)
        XCTAssertEqual(model.collisionRadius.bitPattern, sourceRadius.bitPattern)
        XCTAssertNotEqual(model.collisionRadius, 200)
        XCTAssertEqual(model.submodels[0].vertices, [])
        XCTAssertEqual(model.submodels[1].faces[0].corners.count, 31)
        XCTAssertEqual(
            model.submodels[1].presentation,
            .glow(color: .init(x: 1, y: 0.5, z: 0.25), size: 2)
        )
        XCTAssertEqual(
            model.submodels[1].faces[0].material,
            .texture(.init(storedIndex: 0, sourceName: "Synthetic"))
        )
        XCTAssertEqual(model.sourceSHA256, canonicalSHA256(data))
        let decoded = try JSONDecoder().decode(
            CanonicalModel.self,
            from: JSONEncoder().encode(model)
        )
        XCTAssertEqual(decoded.collisionRadius.bitPattern, sourceRadius.bitPattern)
    }

    func testReachedOOFDiscardsUnreachedVertexNormalsAndRejectsMissingFaceTexture() throws {
        let data = makeReachedOOFWithNonfiniteVertexNormal()
        let texture = SourceResource(storedIndex: 0, sourceName: "Synthetic")

        let model = try parseReachedOutrageModel(
            data,
            sourceName: "Synthetic.OOF",
            sourceArchive: "d3.hog",
            textureResources: [texture]
        )
        let encoded = try JSONEncoder().encode(model)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let submodels = try XCTUnwrap(object["submodels"] as? [[String: Any]])
        let vertices = try XCTUnwrap(submodels[0]["vertices"] as? [[String: Any]])
        XCTAssertNil(vertices[0]["normal"])

        XCTAssertThrowsError(
            try parseReachedOutrageModel(
                data,
                sourceName: "Synthetic.OOF",
                sourceArchive: "d3.hog",
                textureResources: [nil]
            )
        ) {
            XCTAssertEqual(
                $0 as? OutrageModelImportError,
                .invalidIndex("missing texture slot")
            )
        }
    }

    func testReachedOOFResolvesSecurityCameraGunpointThroughItsParentChain() throws {
        let data = makeReachedOOFFixture(
            gunpoint: .init(
                parentSubmodelIndex: 1,
                position: .init(x: 1, y: 2, z: 3),
                forward: .init(x: 0, y: 0, z: -1)
            )
        )
        let gunpoint = try reachedOutrageModelGunpoint(
            data,
            index: 0
        )

        XCTAssertEqual(gunpoint.position, .init(x: 101, y: 2, z: 3))
        XCTAssertEqual(gunpoint.forward, .init(x: 0, y: 0, z: -1))
    }

    func testReachedOOFGunpointRejectsUnsupportedContainerBeforeChunks() {
        let data = makeReachedOOFFixture(
            gunpoint: .init(
                parentSubmodelIndex: 1,
                position: .init(x: 1, y: 2, z: 3),
                forward: .init(x: 0, y: 0, z: -1)
            )
        )
        var badMagic = data
        badMagic[0] = Array("X".utf8)[0]
        XCTAssertThrowsError(
            try reachedOutrageModelGunpoint(badMagic, index: 0)
        ) {
            XCTAssertEqual(
                $0 as? OutrageModelImportError,
                .invalidHeader
            )
        }
        var badVersion = data
        badVersion[4] = 0
        badVersion[5] = 0
        badVersion[6] = 0
        badVersion[7] = 0
        XCTAssertThrowsError(
            try reachedOutrageModelGunpoint(badVersion, index: 0)
        ) {
            XCTAssertEqual(
                $0 as? OutrageModelImportError,
                .unsupportedVersion(0)
            )
        }
    }

    func testRetailSoundPageResolvesPupCAndCanonicalizesPCM16WAV() throws {
        let page = makeRetailSoundTablePage(
            logicalName: "PupC1",
            sourceName: "PupC.wav",
            importVolume: 0.75
        )
        let resolved = try resolveRetailSoundPage(
            table: page,
            overlay: Data(),
            named: "PupC1"
        )
        XCTAssertEqual(resolved.logicalName, "PupC1")
        XCTAssertEqual(resolved.sourceName, "PupC.wav")
        XCTAssertEqual(resolved.importVolume, 0.75)

        let decoded = try decodeReachedPCM16WAV(
            makePCM16WAV(samples: [-32_768, 0, 32_767])
        )
        XCTAssertEqual(decoded.sampleRate, 22_050)
        XCTAssertEqual(decoded.channelCount, 1)
        XCTAssertEqual(decoded.frameCount, 3)
        XCTAssertEqual(
            decoded.pcm16LittleEndian,
            Data([0x00, 0x80, 0x00, 0x00, 0xff, 0x7f])
        )
    }

    func testReachedWAVRejectsTruncatedRIFFDeclaration() {
        var data = makePCM16WAV(samples: [-1, 0, 1])
        let declaredSize = UInt32(data.count - 8 + 4)
        data[4] = UInt8(declaredSize & 0xff)
        data[5] = UInt8((declaredSize >> 8) & 0xff)
        data[6] = UInt8((declaredSize >> 16) & 0xff)
        data[7] = UInt8((declaredSize >> 24) & 0xff)

        XCTAssertThrowsError(try decodeReachedPCM16WAV(data)) {
            XCTAssertEqual($0 as? ReachedWAVDecodeError, .truncated)
        }
    }

    func testBlockedTerminationSignalBecomesACancellationRequest() throws {
        var originalMask = sigset_t()
        XCTAssertEqual(pthread_sigmask(SIG_SETMASK, nil, &originalMask), 0)
        defer {
            var restoredMask = originalMask
            XCTAssertEqual(pthread_sigmask(SIG_SETMASK, &restoredMask, nil), 0)
        }

        blockD3ImportCancellationSignals()
        XCTAssertEqual(pthread_kill(pthread_self(), SIGTERM), 0)
        XCTAssertEqual(pendingD3ImportCancellationSignal(), SIGTERM)
        XCTAssertNil(pendingD3ImportCancellationSignal())
    }

    func testParsesTheVersionedCompleteTrainingContract() throws {
        let arguments = try D3ImportArguments.parse([
            "D3Import",
            "--contract", "1",
            "--source", "/prepared",
            "--staging", "/output/.candidate",
            "--destination", "/output/training.revival",
            "--scope", "descent3.level.training-mission",
            "--report", "/output/report.json",
        ])

        XCTAssertEqual(arguments.contract, 1)
        XCTAssertEqual(arguments.source.path, "/prepared")
        XCTAssertEqual(arguments.staging.path, "/output/.candidate")
        XCTAssertEqual(arguments.destination.path, "/output/training.revival")
        XCTAssertEqual(arguments.scope, "descent3.level.training-mission")
        XCTAssertEqual(arguments.report.path, "/output/report.json")
    }

    func testValidatesEveryExactPreparedProfileFingerprint() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root.appending(path: "missions", directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )
        let first = Data("archive".utf8)
        let second = Data("mission".utf8)
        try first.write(to: root.appending(path: "d3.hog"))
        try second.write(to: root.appending(path: "missions/training.mn3"))
        let profile = PreparedRetailProfile(
            identifier: "test",
            files: [
                .init(relativePath: "d3.hog", byteCount: first.count, sha256: canonicalSHA256(first)),
                .init(
                    relativePath: "missions/training.mn3",
                    byteCount: second.count,
                    sha256: canonicalSHA256(second)
                ),
            ]
        )

        let validated = try profile.files.map {
            try readValidatedPreparedRetailFile($0, at: root)
        }
        XCTAssertEqual(validated.map(\.file), profile.files)
        XCTAssertEqual(validated.map(\.data), [first, second])

        try Data("changed".utf8).write(to: root.appending(path: "d3.hog"))
        XCTAssertThrowsError(try readValidatedPreparedRetailFile(profile.files[0], at: root)) {
            XCTAssertEqual(
                $0 as? D3ImportOperationError,
                .preparedFileDigestMismatch("d3.hog")
            )
        }
    }

    func testParsesTheSameValidatedSnapshotThatWasHashed() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let original = Data("original archive bytes".utf8)
        let url = root.appending(path: "d3.hog")
        try original.write(to: url)
        let file = PreparedRetailFile(
            relativePath: "d3.hog",
            byteCount: original.count,
            sha256: canonicalSHA256(original)
        )

        let validated = try readValidatedPreparedRetailFile(file, at: root)
        try Data("replacement bytes".utf8).write(to: url, options: .atomic)

        XCTAssertEqual(validated.data, original)
        XCTAssertEqual(canonicalSHA256(validated.data), file.sha256)
    }

    func testRejectsSymlinkedPreparedPathComponents() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let real = root.appending(path: "real", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        let data = Data("archive".utf8)
        try data.write(to: real.appending(path: "d3.hog"))
        try FileManager.default.createSymbolicLink(
            at: root.appending(path: "linked"),
            withDestinationURL: real
        )
        let file = PreparedRetailFile(
            relativePath: "linked/d3.hog",
            byteCount: data.count,
            sha256: canonicalSHA256(data)
        )

        XCTAssertThrowsError(try readValidatedPreparedRetailFile(file, at: root)) { error in
            XCTAssertEqual(error as? D3ImportOperationError, .invalidPreparedFile(file.relativePath))
        }
    }

    func testPromotesValidatedCandidate() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let destination = root.appending(path: "training.revival", directoryHint: .isDirectory)
        let staging = root.appending(path: ".candidate", directoryHint: .isDirectory)
        let report = root.appending(path: "report.json")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)

        let prior = makeMinimalCanonicalPackageLevel(levelKey: "test.level.prior")
        let successor = makeMinimalCanonicalPackageLevel(levelKey: "test.level.successor")
        try writeCanonicalPackage(prior, to: destination)
        try writeCanonicalPackage(successor, to: staging)
        let reportData = Data("{\"result\":\"ok\"}".utf8)

        try promoteCanonicalPackage(
            from: staging,
            to: destination,
            reportData: reportData,
            reportURL: report,
            cancellationCheck: { nil }
        )

        XCTAssertEqual(try loadCanonicalLevel(from: destination), successor)
        XCTAssertFalse(FileManager.default.fileExists(atPath: staging.path))
        XCTAssertEqual(try Data(contentsOf: report), reportData)
    }

    func testPreservesAnUnrelatedDestinationOccupant() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let destination = root.appending(path: "training.revival")
        let staging = root.appending(path: ".candidate", directoryHint: .isDirectory)
        let report = root.appending(path: "report.json")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)

        let fixtureURL = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "test", withExtension: "hog")
        )
        let unrelatedData = try Data(contentsOf: fixtureURL)
        let priorReport = Data("{\"result\":\"prior\"}".utf8)
        let successor = makeMinimalCanonicalPackageLevel(levelKey: "test.level.successor")
        try unrelatedData.write(to: destination)
        try priorReport.write(to: report)
        try writeCanonicalPackage(successor, to: staging)

        XCTAssertThrowsError(
            try promoteCanonicalPackage(
                from: staging,
                to: destination,
                reportData: Data("{\"result\":\"successor\"}".utf8),
                reportURL: report,
                cancellationCheck: { nil }
            )
        ) { error in
            XCTAssertEqual(error as? CanonicalPackageError, .invalidPackageDirectory)
        }
        XCTAssertEqual(try Data(contentsOf: destination), unrelatedData)
        XCTAssertEqual(try loadCanonicalLevel(from: staging), successor)
        XCTAssertEqual(try Data(contentsOf: report), priorReport)
    }

    func testPathValidationRejectsReportInsidePackage() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let source = root.appending(path: "source", directoryHint: .isDirectory)
        let staging = root.appending(path: ".candidate", directoryHint: .isDirectory)
        let destination = root.appending(path: "training.revival", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: false)
        try writeCanonicalPackage(makeMinimalCanonicalPackageLevel(), to: destination)

        XCTAssertThrowsError(
            try validateD3ImportPaths(
                .init(
                    contract: 1,
                    source: source,
                    staging: staging,
                    destination: destination,
                    scope: "descent3.level.training-mission",
                    report: destination.appending(path: "content.json")
                )
            )
        ) { error in
            XCTAssertEqual(error as? D3ImportOperationError, .invalidOutputPath)
        }
    }

    func testPathValidationRejectsDirectoryReport() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let source = root.appending(path: "source", directoryHint: .isDirectory)
        let staging = root.appending(path: ".candidate", directoryHint: .isDirectory)
        let destination = root.appending(path: "training.revival", directoryHint: .isDirectory)
        let invalidReport = root.appending(path: "report.json", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: invalidReport, withIntermediateDirectories: false)

        XCTAssertThrowsError(
            try validateD3ImportPaths(
                .init(
                    contract: 1,
                    source: source,
                    staging: staging,
                    destination: destination,
                    scope: "descent3.level.training-mission",
                    report: invalidReport
                )
            )
        ) { error in
            XCTAssertEqual(error as? D3ImportOperationError, .invalidOutputPath)
        }
    }

    func testCancellationBeforePackageCommitRestoresPriorPackageAndReport() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let staging = root.appending(path: ".candidate", directoryHint: .isDirectory)
        let destination = root.appending(path: "training.revival", directoryHint: .isDirectory)
        let report = root.appending(path: "report.json")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let prior = makeMinimalCanonicalPackageLevel(levelKey: "test.level.prior")
        let successor = makeMinimalCanonicalPackageLevel(levelKey: "test.level.successor")
        let priorReport = Data("{\"result\":\"prior\"}".utf8)
        try writeCanonicalPackage(prior, to: destination)
        try writeCanonicalPackage(successor, to: staging)
        try priorReport.write(to: report)
        var cancellationChecks = 0

        XCTAssertThrowsError(
            try promoteCanonicalPackage(
                from: staging,
                to: destination,
                reportData: Data("{\"result\":\"successor\"}".utf8),
                reportURL: report,
                cancellationCheck: {
                    cancellationChecks += 1
                    return cancellationChecks == 2 ? SIGTERM : nil
                }
            )
        ) { error in
            XCTAssertEqual(error as? D3ImportOperationError, .cancelled(SIGTERM))
        }
        XCTAssertEqual(try loadCanonicalLevel(from: destination), prior)
        XCTAssertEqual(try loadCanonicalLevel(from: staging), successor)
        XCTAssertEqual(try Data(contentsOf: report), priorReport)
        XCTAssertEqual(
            Set(try FileManager.default.contentsOfDirectory(atPath: root.path)),
            [".candidate", "report.json", "training.revival"]
        )
    }

    func testPackagePromotionIsTheFinalCommitPoint() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let staging = root.appending(path: ".candidate", directoryHint: .isDirectory)
        let destination = root.appending(path: "training.revival", directoryHint: .isDirectory)
        let report = root.appending(path: "report.json")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let prior = makeMinimalCanonicalPackageLevel(levelKey: "test.level.prior")
        let successor = makeMinimalCanonicalPackageLevel(levelKey: "test.level.successor")
        let priorReport = Data("{\"result\":\"prior\"}".utf8)
        try writeCanonicalPackage(prior, to: destination)
        try writeCanonicalPackage(successor, to: staging)
        try priorReport.write(to: report)
        var cancellationChecks = 0

        let successorReport = Data("{\"result\":\"successor\"}".utf8)
        try promoteCanonicalPackage(
            from: staging,
            to: destination,
            reportData: successorReport,
            reportURL: report,
            cancellationCheck: {
                cancellationChecks += 1
                return cancellationChecks == 3 ? SIGTERM : nil
            }
        )
        XCTAssertEqual(cancellationChecks, 2)
        XCTAssertEqual(try loadCanonicalLevel(from: destination), successor)
        XCTAssertFalse(FileManager.default.fileExists(atPath: staging.path))
        XCTAssertEqual(try Data(contentsOf: report), successorReport)
        XCTAssertEqual(
            Set(try FileManager.default.contentsOfDirectory(atPath: root.path)),
            ["report.json", "training.revival"]
        )
    }

    func testFirstInstallCancellationBeforePackageCommitRestoresTheCandidate() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let staging = root.appending(path: ".candidate", directoryHint: .isDirectory)
        let destination = root.appending(path: "training.revival", directoryHint: .isDirectory)
        let report = root.appending(path: "report.json")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let successor = makeMinimalCanonicalPackageLevel(levelKey: "test.level.successor")
        try writeCanonicalPackage(successor, to: staging)
        var cancellationChecks = 0

        XCTAssertThrowsError(
            try promoteCanonicalPackage(
                from: staging,
                to: destination,
                reportData: Data("{\"result\":\"successor\"}".utf8),
                reportURL: report,
                cancellationCheck: {
                    cancellationChecks += 1
                    return cancellationChecks == 2 ? SIGTERM : nil
                }
            )
        ) { error in
            XCTAssertEqual(error as? D3ImportOperationError, .cancelled(SIGTERM))
        }
        XCTAssertEqual(try loadCanonicalLevel(from: staging), successor)
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: report.path))
        XCTAssertEqual(
            Set(try FileManager.default.contentsOfDirectory(atPath: root.path)),
            [".candidate"]
        )
    }

    func testReportPromotionFailureOccursBeforePackageCommit() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let staging = root.appending(path: ".candidate", directoryHint: .isDirectory)
        let destination = root.appending(path: "training.revival", directoryHint: .isDirectory)
        let report = root.appending(path: "report.json")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let prior = makeMinimalCanonicalPackageLevel(levelKey: "test.level.prior")
        let successor = makeMinimalCanonicalPackageLevel(levelKey: "test.level.successor")
        let priorReport = Data("{\"result\":\"prior\"}".utf8)
        try writeCanonicalPackage(prior, to: destination)
        try writeCanonicalPackage(successor, to: staging)
        try priorReport.write(to: report)
        XCTAssertEqual(chflags(report.path, UInt32(UF_IMMUTABLE)), 0)
        defer {
            _ = chflags(report.path, 0)
            try? FileManager.default.removeItem(at: root)
        }

        XCTAssertThrowsError(
            try promoteCanonicalPackage(
                from: staging,
                to: destination,
                reportData: Data("{\"result\":\"successor\"}".utf8),
                reportURL: report,
                cancellationCheck: { nil }
            )
        ) { error in
            XCTAssertEqual(error as? D3ImportOperationError, .reportPromotionFailed)
        }
        XCTAssertEqual(try loadCanonicalLevel(from: destination), prior)
        XCTAssertEqual(try loadCanonicalLevel(from: staging), successor)
        XCTAssertEqual(try Data(contentsOf: report), priorReport)
    }

    func testPackagePromotionFailureRestoresPriorReport() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let staging = root.appending(path: ".candidate", directoryHint: .isDirectory)
        let destination = root.appending(path: "training.revival", directoryHint: .isDirectory)
        let report = root.appending(path: "report.json")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let prior = makeMinimalCanonicalPackageLevel(levelKey: "test.level.prior")
        let successor = makeMinimalCanonicalPackageLevel(levelKey: "test.level.successor")
        let priorReport = Data("{\"result\":\"prior\"}".utf8)
        let successorReport = Data("{\"result\":\"successor\"}".utf8)
        try writeCanonicalPackage(prior, to: destination)
        try writeCanonicalPackage(successor, to: staging)
        try priorReport.write(to: report)
        XCTAssertEqual(chflags(destination.path, UInt32(UF_IMMUTABLE)), 0)
        defer {
            _ = chflags(destination.path, 0)
            try? FileManager.default.removeItem(at: root)
        }

        XCTAssertThrowsError(
            try promoteCanonicalPackage(
                from: staging,
                to: destination,
                reportData: successorReport,
                reportURL: report,
                cancellationCheck: { nil }
            )
        ) { error in
            XCTAssertEqual(error as? D3ImportOperationError, .packagePromotionFailed)
        }
        XCTAssertEqual(try loadCanonicalLevel(from: destination), prior)
        XCTAssertEqual(try loadCanonicalLevel(from: staging), successor)
        XCTAssertEqual(try Data(contentsOf: report), priorReport)
    }

    func testConcurrentWritersCannotPublishAMismatchedPackageAndReport() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let stagingA = root.appending(path: ".candidate-a", directoryHint: .isDirectory)
        let stagingB = root.appending(path: ".candidate-b", directoryHint: .isDirectory)
        let destination = root.appending(path: "training.revival", directoryHint: .isDirectory)
        let report = root.appending(path: "report.json")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let prior = makeMinimalCanonicalPackageLevel(levelKey: "test.level.prior")
        let levelA = makeMinimalCanonicalPackageLevel(levelKey: "test.level.writer-a")
        let levelB = makeMinimalCanonicalPackageLevel(levelKey: "test.level.writer-b")
        let reportA = Data("{\"levelKey\":\"test.level.writer-a\"}".utf8)
        let reportB = Data("{\"levelKey\":\"test.level.writer-b\"}".utf8)
        try writeCanonicalPackage(prior, to: destination)
        try writeCanonicalPackage(levelA, to: stagingA)
        try writeCanonicalPackage(levelB, to: stagingB)
        try Data("{\"levelKey\":\"test.level.prior\"}".utf8).write(to: report)

        let aBeforePackageCommit = DispatchSemaphore(value: 0)
        let bBeforePackageCommit = DispatchSemaphore(value: 0)
        let releaseA = DispatchSemaphore(value: 0)
        let releaseB = DispatchSemaphore(value: 0)
        let aFinished = DispatchSemaphore(value: 0)
        let bFinished = DispatchSemaphore(value: 0)
        let outcomeA = PromotionOutcome()
        let outcomeB = PromotionOutcome()

        DispatchQueue.global().async {
            outcomeA.capture {
                var checks = 0
                try promoteCanonicalPackage(
                    from: stagingA,
                    to: destination,
                    reportData: reportA,
                    reportURL: report,
                    cancellationCheck: {
                        checks += 1
                        if checks == 2 {
                            aBeforePackageCommit.signal()
                            releaseA.wait()
                        }
                        return nil
                    }
                )
            }
            aFinished.signal()
        }
        XCTAssertEqual(aBeforePackageCommit.wait(timeout: .now() + 5), .success)

        DispatchQueue.global().async {
            outcomeB.capture {
                var checks = 0
                try promoteCanonicalPackage(
                    from: stagingB,
                    to: destination,
                    reportData: reportB,
                    reportURL: report,
                    cancellationCheck: {
                        checks += 1
                        if checks == 2 {
                            bBeforePackageCommit.signal()
                            releaseB.wait()
                        }
                        return nil
                    }
                )
            }
            bFinished.signal()
        }

        if bBeforePackageCommit.wait(timeout: .now() + 2) == .success {
            releaseB.signal()
            XCTAssertEqual(bFinished.wait(timeout: .now() + 5), .success)
            releaseA.signal()
            XCTAssertEqual(aFinished.wait(timeout: .now() + 5), .success)
        } else {
            releaseA.signal()
            XCTAssertEqual(aFinished.wait(timeout: .now() + 5), .success)
            XCTAssertEqual(bBeforePackageCommit.wait(timeout: .now() + 5), .success)
            releaseB.signal()
            XCTAssertEqual(bFinished.wait(timeout: .now() + 5), .success)
        }

        XCTAssertNil(outcomeA.error)
        XCTAssertNil(outcomeB.error)
        let installed = try loadCanonicalLevel(from: destination)
        let installedReport = try Data(contentsOf: report)
        XCTAssertTrue(
            (installed == levelA && installedReport == reportA)
                || (installed == levelB && installedReport == reportB)
        )
    }

    func testBuildsDeterministicPathFreeReportFromCanonicalLevel() throws {
        let base = makeMinimalCanonicalLevel()
        let roomThree = replacing(
            base.rooms[0],
            sourceIndex: 3,
            portals: [.init(faceIndex: 0, connectedRoom: 4, connectedPortal: 0)]
        )
        let roomFour = replacing(
            base.rooms[1],
            portals: [.init(faceIndex: 0, connectedRoom: 3, connectedPortal: 0)]
        )
        let level = replacing(base, rooms: [roomThree, roomFour])
        let inventories = [
            PreparedArchiveInventory(
                relativePath: "missions/training.mn3",
                byteCount: 12,
                sha256: "archive-digest",
                entryCount: 3
            ),
        ]

        let report = makeD3ImportReport(
            level: level,
            scope: level.levelKey,
            archives: inventories,
            packageContentSHA256: "content-digest",
            packageLevelSHA256: "level-digest"
        )
        let first = try canonicalJSONData(report)
        let second = try canonicalJSONData(report)

        XCTAssertEqual(first, second)
        XCTAssertEqual(report.counts.usedRooms, 2)
        XCTAssertEqual(report.counts.faces, 2)
        XCTAssertEqual(report.counts.directedPortals, 2)
        XCTAssertEqual(report.counts.terrainCells, 65_536)
        XCTAssertTrue(report.promotionOccurred)
        XCTAssertEqual(report.result, "promoted")
        XCTAssertFalse(String(decoding: first, as: UTF8.self).contains("/prepared"))
    }

    func testValidatesSourcePackageStagingAndReportPathRelationships() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let source = root.appending(path: "source", directoryHint: .isDirectory)
        let output = root.appending(path: "output", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        func arguments(staging: URL, destination: URL, report: URL) -> D3ImportArguments {
            D3ImportArguments(
                contract: 1,
                source: source,
                staging: staging,
                destination: destination,
                scope: "descent3.level.training-mission",
                report: report
            )
        }

        let staging = output.appending(path: "candidate", directoryHint: .isDirectory)
        let destination = output.appending(path: "installed", directoryHint: .isDirectory)
        XCTAssertNoThrow(
            try validateD3ImportPaths(
                arguments(
                    staging: staging,
                    destination: destination,
                    report: output.appending(path: "report.json")
                )
            )
        )
        XCTAssertThrowsError(
            try validateD3ImportPaths(
                arguments(
                    staging: destination,
                    destination: destination,
                    report: output.appending(path: "report.json")
                )
            )
        ) { error in
            XCTAssertEqual(
                error as? D3ImportOperationError,
                .stagingIsNotDestinationAdjacent
            )
        }
        XCTAssertThrowsError(
            try validateD3ImportPaths(
                arguments(
                    staging: source.appending(path: "candidate"),
                    destination: source.appending(path: "installed"),
                    report: source.appending(path: "report.json")
                )
            )
        ) { error in
            XCTAssertEqual(error as? D3ImportOperationError, .overlappingPaths)
        }
        XCTAssertThrowsError(
            try validateD3ImportPaths(
                arguments(
                    staging: staging,
                    destination: destination,
                    report: source.appending(path: "report.json")
                )
            )
        ) { error in
            XCTAssertEqual(error as? D3ImportOperationError, .invalidOutputPath)
        }
        XCTAssertThrowsError(
            try validateD3ImportPaths(
                arguments(
                    staging: output.appending(path: ".Candidate"),
                    destination: output.appending(path: ".candidate"),
                    report: output.appending(path: "report.json")
                )
            )
        ) { error in
            XCTAssertEqual(
                error as? D3ImportOperationError,
                .stagingIsNotDestinationAdjacent
            )
        }
        XCTAssertThrowsError(
            try validateD3ImportPaths(
                arguments(
                    staging: staging,
                    destination: destination,
                    report: output.appending(path: "INSTALLED")
                )
            )
        ) { error in
            XCTAssertEqual(error as? D3ImportOperationError, .overlappingPaths)
        }
        XCTAssertThrowsError(
            try validateD3ImportPaths(
                arguments(
                    staging: root.appending(path: "SOURCE"),
                    destination: root.appending(path: "installed"),
                    report: root.appending(path: "report.json")
                )
            )
        ) { error in
            XCTAssertEqual(error as? D3ImportOperationError, .overlappingPaths)
        }
    }
}

private func makeReachedOOFFixture(
    properties: String = "$glow=1, 0.5, 0.25, 2",
    collisionRadius: Float = 200,
    gunpoint: ReachedModelGunpoint? = nil
) -> Data {
    var data = Data("PSPO".utf8)
    data.appendInt32(2_300)

    var header = Data()
    header.appendInt32(2)
    header.appendFloat(collisionRadius)
    header.appendVector(.zero)
    header.appendVector(.zero)
    header.appendInt32(0)
    data.appendChunk("OHDR", body: header)

    var textures = Data()
    textures.appendInt32(1)
    textures.appendModelString("SAMPLE TEXTURE")
    data.appendChunk("TXTR", body: textures)

    data.appendChunk(
        "SOBJ",
        body: makeReachedSOBJ(
            index: 0,
            parent: -1,
            offset: .init(x: 100, y: 0, z: 0),
            properties: "",
            vertices: [],
            faceVertexIndices: []
        )
    )
    let vertices = (0..<31).map { index -> Vector3 in
        let angle = Float(index) * 2 * .pi / 31
        return .init(x: 5 + cos(angle), y: sin(angle), z: 2)
    }
    data.appendChunk(
        "SOBJ",
        body: makeReachedSOBJ(
            index: 1,
            parent: 0,
            offset: .init(x: 0, y: 0, z: 0),
            properties: properties,
            vertices: vertices,
            faceVertexIndices: Array(vertices.indices)
        )
    )
    var rotation = Data()
    for submodelIndex in 0..<2 {
        rotation.appendInt32(2)
        rotation.appendInt32(0)
        rotation.appendInt32(1)
        rotation.appendInt32(0)
        rotation.appendVector(.init(x: 1, y: 0, z: 0))
        rotation.appendInt32(0)
        rotation.appendInt32(1)
        rotation.appendVector(
            submodelIndex == 1
                ? .init(x: 0, y: 2, z: 0)
                : .init(x: 1, y: 0, z: 0)
        )
        rotation.appendInt32(0)
    }
    data.appendChunk("RANI", body: rotation)
    if let gunpoint {
        var body = Data()
        body.appendInt32(1)
        body.appendInt32(Int32(gunpoint.parentSubmodelIndex))
        body.appendVector(gunpoint.position)
        body.appendVector(gunpoint.forward)
        data.appendChunk("GPNT", body: body)
    }
    return data
}

private func makeRetailSoundTablePage(
    logicalName: String,
    sourceName: String,
    importVolume: Float
) -> Data {
    var body = Data()
    body.appendUInt16(1)
    body.appendCString(logicalName)
    body.appendCString(sourceName)
    body.appendInt32(0)
    body.appendInt32(0)
    body.appendInt32(0)
    body.appendFloat(360)
    body.appendInt32(360)
    body.appendInt32(360)
    body.appendFloat(1_000)
    body.appendFloat(0)
    body.appendFloat(importVolume)
    var table = Data([7])
    table.appendUInt32(UInt32(body.count + 4))
    table.append(body)
    return table
}

private func makePCM16WAV(samples: [Int16]) -> Data {
    var pcm = Data()
    for sample in samples {
        pcm.append(UInt8(truncatingIfNeeded: sample))
        pcm.append(UInt8(truncatingIfNeeded: sample >> 8))
    }
    var data = Data("RIFF".utf8)
    data.appendUInt32(UInt32(36 + pcm.count))
    data.append(Data("WAVEfmt ".utf8))
    data.appendUInt32(16)
    data.appendUInt16(1)
    data.appendUInt16(1)
    data.appendUInt32(22_050)
    data.appendUInt32(44_100)
    data.appendUInt16(2)
    data.appendUInt16(16)
    data.append(Data("data".utf8))
    data.appendUInt32(UInt32(pcm.count))
    data.append(pcm)
    return data
}

private func makeRetailShipTablePage() -> Data {
    var body = Data()
    body.appendUInt16(6)
    body.appendCString("Pyro-GL")
    body.appendCString("PyroCockpit")
    body.appendCString("PyroHUD")
    body.appendCString("PyroGL.OOF")
    body.appendCString("PyroGLDying.OOF")
    body.appendCString("PyroGLMed.OOF")
    body.appendCString("PyroGLLow.OOF")
    body.appendFloat(70)
    body.appendFloat(120)
    body.appendFloat(30)
    body.appendFloat(90)
    body.appendFloat(5_400)
    body.appendInt32(0x49)
    body.appendFloat(225)
    body.appendFloat(6_860_000)
    body.appendInt32(-1)
    body.appendFloat(0)
    body.appendVector(.zero)
    body.appendFloat(0.17)
    body.appendFloat(0.9)
    body.appendFloat(1)
    body.appendFloat(-1)
    body.appendFloat(8_000)
    body.appendFloat(0.13)
    body.appendFloat(6.676084041595459)
    body.appendFloat(1)
    body.appendInt32(1)

    var table = Data([6])
    table.appendUInt32(UInt32(body.count + 4))
    table.append(body)
    return table
}

private func makeRetailGenericModelTablePage() -> Data {
    var body = Data()
    body.appendUInt16(25)
    body.append(7)
    body.appendCString("Invisiblepowerup")
    body.appendCString("invisiblepowerup.OOF")
    body.appendCString("")
    body.appendCString("")
    body.append(Data(repeating: 0, count: 16))
    body.appendCString("")
    body.appendCString("")
    body.appendCString("")
    body.append(0)
    body.appendCString("")
    body.appendFloat(0)
    body.appendFloat(0)

    var table = Data([10])
    table.appendUInt32(UInt32(body.count + 4))
    table.append(body)
    return table
}

private func makeReachedOOFWithNonfiniteVertexNormal() -> Data {
    var data = Data("PSPO".utf8)
    data.appendInt32(2_300)

    var header = Data()
    header.appendInt32(1)
    header.appendFloat(1)
    header.appendVector(.zero)
    header.appendVector(.zero)
    header.appendInt32(0)
    data.appendChunk("OHDR", body: header)

    var textures = Data()
    textures.appendInt32(1)
    textures.appendModelString("Synthetic")
    data.appendChunk("TXTR", body: textures)
    data.appendChunk(
        "SOBJ",
        body: makeReachedSOBJ(
            index: 0,
            parent: -1,
            offset: .zero,
            properties: "",
            vertices: [
                .init(x: 0, y: 0, z: 0),
                .init(x: 1, y: 0, z: 0),
                .init(x: 0, y: 1, z: 0),
                .init(x: 2, y: 2, z: 2),
            ],
            normals: [
                .init(x: .nan, y: .nan, z: .nan),
                .init(x: 0, y: 0, z: 1),
                .init(x: 0, y: 0, z: 1),
                .init(x: .nan, y: .nan, z: .nan),
            ],
            faceVertexIndices: [0, 1, 2]
        )
    )
    return data
}

private func makeReachedSOBJ(
    index: Int32,
    parent: Int32,
    offset: Vector3,
    properties: String,
    vertices: [Vector3],
    normals: [Vector3]? = nil,
    faceVertexIndices: [Int]
) -> Data {
    var body = Data()
    body.appendInt32(index)
    body.appendInt32(parent)
    body.appendVector(.zero)
    body.appendFloat(0)
    body.appendVector(.zero)
    body.appendVector(offset)
    body.appendFloat(1)
    body.appendInt32(0)
    body.appendInt32(0)
    body.appendVector(.zero)
    body.appendModelString("submodel-\(index)")
    body.appendModelString(properties)
    body.appendInt32(0)
    body.appendInt32(0)
    body.appendInt32(0)
    body.appendInt32(Int32(vertices.count))
    vertices.forEach { body.appendVector($0) }
    (normals ?? vertices.map { _ in .init(x: 0, y: 0, z: 1) })
        .forEach { body.appendVector($0) }
    vertices.forEach { _ in body.appendFloat(1) }
    body.appendInt32(faceVertexIndices.isEmpty ? 0 : 1)
    if !faceVertexIndices.isEmpty {
        body.appendVector(.init(x: 0, y: 0, z: 1))
        body.appendInt32(Int32(faceVertexIndices.count))
        body.appendInt32(1)
        body.appendInt32(0)
        for index in faceVertexIndices {
            body.appendInt32(Int32(index))
            body.appendFloat(0)
            body.appendFloat(0)
        }
        body.appendFloat(0)
        body.appendFloat(0)
    }
    return body
}

private extension Data {
    mutating func appendChunk(_ name: String, body: Data) {
        append(contentsOf: name.utf8)
        appendInt32(Int32(body.count))
        append(body)
    }

    mutating func appendInt32(_ value: Int32) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendUInt16(_ value: UInt16) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendUInt32(_ value: UInt32) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendFloat(_ value: Float) {
        appendInt32(Int32(bitPattern: value.bitPattern))
    }

    mutating func appendVector(_ value: Vector3) {
        appendFloat(value.x)
        appendFloat(value.y)
        appendFloat(value.z)
    }

    mutating func appendModelString(_ value: String) {
        appendInt32(Int32(value.utf8.count + 1))
        append(contentsOf: value.utf8)
        append(0)
    }

    mutating func appendCString(_ value: String) {
        append(contentsOf: value.utf8)
        append(0)
    }
}

private final class PromotionOutcome: @unchecked Sendable {
    private let lock = NSLock()
    private var capturedError: Error?

    var error: Error? {
        lock.withLock { capturedError }
    }

    func capture(_ operation: () throws -> Void) {
        do {
            try operation()
        } catch {
            lock.withLock { capturedError = error }
        }
    }
}
