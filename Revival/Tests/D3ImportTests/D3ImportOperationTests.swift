import Darwin
import XCTest

final class D3ImportOperationTests: XCTestCase {
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
