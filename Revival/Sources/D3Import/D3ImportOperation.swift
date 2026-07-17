// SPDX-License-Identifier: GPL-3.0-or-later

import Darwin
import Foundation

struct PreparedArchiveInventory: Codable, Equatable, Sendable {
    let relativePath: String
    let byteCount: Int
    let sha256: String
    let entryCount: Int
}

struct CanonicalLevelCounts: Codable, Equatable, Sendable {
    let usedRooms: Int
    let roomVertices: Int
    let faces: Int
    let faceVertices: Int
    let directedPortals: Int
    let usedObjects: Int
    let terrainCells: Int
    let paths: Int
    let goals: Int
    let triggers: Int
    let lightmapInfos: Int
}

struct DependencyCategoryCount: Codable, Equatable, Sendable {
    let category: String
    let count: Int
}

struct RoomPortalEvidence: Codable, Equatable, Sendable {
    let index: Int
    let faceIndex: Int
    let connectedRoom: Int
    let connectedPortal: Int
    let flags: UInt32
}

struct RoomObjectEvidence: Codable, Equatable, Sendable {
    let slot: Int
    let type: UInt8
    let storedID: Int
    let sourceName: String
    let referenceRuntimeIndex: Int?
    let instanceName: String?
}

struct RoomThreeEvidence: Codable, Equatable, Sendable {
    let faces: Int
    let portals: [RoomPortalEvidence]
    let objects: [RoomObjectEvidence]
}

struct CanonicalPackageDigests: Codable, Equatable, Sendable {
    let contentSHA256: String
    let levelSHA256: String
}

struct D3ImportReport: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let contract: Int
    let result: String
    let promotionOccurred: Bool
    let diagnostics: [String]
    let scope: String
    let completedMissionKeys: [String]
    let completedLevelKeys: [String]
    let profileIdentifier: String
    let missionKey: String
    let levelKey: String
    let source: LevelSource
    let archives: [PreparedArchiveInventory]
    let usedRoomSourceIndices: [Int]
    let counts: CanonicalLevelCounts
    let roomThree: RoomThreeEvidence
    let dependencies: [DependencyCategoryCount]
    let currentDependencies: [DependencyRecord]
    let sourceEntries: [SourceChunkRecord]
    let historicalEagerBaseline: EagerDependencyBaseline?
    let package: CanonicalPackageDigests
}

typealias D3ImportCancellationCheck = () -> Int32?

func blockD3ImportCancellationSignals() {
    var signals = sigset_t()
    precondition(sigemptyset(&signals) == 0)
    precondition(sigaddset(&signals, SIGINT) == 0)
    precondition(sigaddset(&signals, SIGTERM) == 0)
    let result = pthread_sigmask(SIG_BLOCK, &signals, nil)
    precondition(result == 0)
}

func pendingD3ImportCancellationSignal() -> Int32? {
    var pending = sigset_t()
    precondition(sigpending(&pending) == 0)
    for signal in [SIGINT, SIGTERM] where sigismember(&pending, signal) == 1 {
        var selected = sigset_t()
        precondition(sigemptyset(&selected) == 0)
        precondition(sigaddset(&selected, signal) == 0)
        var observed: Int32 = 0
        let result = sigwait(&selected, &observed)
        precondition(result == 0)
        return observed
    }
    return nil
}

func makeD3ImportReport(
    level: Level,
    scope: String,
    archives: [PreparedArchiveInventory],
    packageContentSHA256: String,
    packageLevelSHA256: String
) -> D3ImportReport {
    let room = level.rooms.first(where: { $0.sourceIndex == 3 })!
    let roomThree = RoomThreeEvidence(
        faces: room.faces.count,
        portals: room.portals.enumerated().map { index, portal in
            RoomPortalEvidence(
                index: index,
                faceIndex: portal.faceIndex,
                connectedRoom: portal.connectedRoom,
                connectedPortal: portal.connectedPortal,
                flags: portal.flags
            )
        },
        objects: level.objects.filter {
            if case .room(3) = $0.location { return true }
            return false
        }.map { object in
            let definition = object.definition!
            return RoomObjectEvidence(
                slot: object.slot,
                type: object.type,
                storedID: object.storedID,
                sourceName: definition.sourceName,
                referenceRuntimeIndex: definition.referenceRuntimeIndex,
                instanceName: object.instanceName
            )
        }
    )
    let groupedDependencies = Dictionary(grouping: level.dependencyManifest.current, by: \.category)
    return D3ImportReport(
        schemaVersion: 2,
        contract: 1,
        result: "promoted",
        promotionOccurred: true,
        diagnostics: [],
        scope: scope,
        completedMissionKeys: [level.missionKey],
        completedLevelKeys: [level.levelKey],
        profileIdentifier: level.source.profileIdentifier,
        missionKey: level.missionKey,
        levelKey: level.levelKey,
        source: level.source,
        archives: archives,
        usedRoomSourceIndices: level.rooms.map(\.sourceIndex),
        counts: CanonicalLevelCounts(
            usedRooms: level.rooms.count,
            roomVertices: level.rooms.reduce(0) { $0 + $1.vertices.count },
            faces: level.rooms.reduce(0) { $0 + $1.faces.count },
            faceVertices: level.rooms.reduce(0) { count, room in
                count + room.faces.reduce(0) { $0 + $1.corners.count }
            },
            directedPortals: level.rooms.reduce(0) { $0 + $1.portals.count },
            usedObjects: level.objects.count,
            terrainCells: level.terrain.heights.count,
            paths: level.paths.count,
            goals: level.goals.count,
            triggers: level.triggers.count,
            lightmapInfos: level.lightmaps.infos.count
        ),
        roomThree: roomThree,
        dependencies: groupedDependencies.sorted(by: { $0.key < $1.key }).map {
            DependencyCategoryCount(category: $0.key, count: $0.value.count)
        },
        currentDependencies: level.dependencyManifest.current,
        sourceEntries: level.sourceChunks,
        historicalEagerBaseline: level.dependencyManifest.historicalEagerBaseline,
        package: CanonicalPackageDigests(
            contentSHA256: packageContentSHA256,
            levelSHA256: packageLevelSHA256
        )
    )
}

@discardableResult
func runD3Import(
    _ arguments: D3ImportArguments,
    cancellationCheck: D3ImportCancellationCheck
) throws -> D3ImportReport {
    try throwIfD3ImportCancelled(cancellationCheck)
    try validateD3ImportPaths(arguments)

    let profile = PreparedRetailProfile.training
    let trainingFile = profile.files.first {
        $0.relativePath == "missions/training.mn3"
    }!
    let training = try readValidatedPreparedRetailFile(trainingFile, at: arguments.source)
    let trainingArchive = try! parseHOG2(training.data)
    let inventories = try profile.files.map { file in
        let validated: ValidatedPreparedRetailFile
        let archive: HOG2Archive
        if file.relativePath == trainingFile.relativePath {
            validated = training
            archive = trainingArchive
        } else {
            validated = try readValidatedPreparedRetailFile(file, at: arguments.source)
            archive = try! parseHOG2(validated.data)
        }
        return PreparedArchiveInventory(
            relativePath: validated.file.relativePath,
            byteCount: validated.file.byteCount,
            sha256: validated.file.sha256,
            entryCount: archive.entries.count
        )
    }
    let trainingData = training.data

    let descriptorEntry = trainingArchive.uniqueEntry(named: "training.msn")
    let mission = try! parseTrainingMission(trainingData.subdata(in: descriptorEntry.payloadRange))
    let levelEntry = trainingArchive.uniqueEntry(named: mission.mineSourceName)
    let levelData = trainingData.subdata(in: levelEntry.payloadRange)

    let source = LevelSource(
        profileIdentifier: profile.identifier,
        profileFiles: profile.files.map {
            SourceFileFingerprint(
                relativePath: $0.relativePath,
                byteCount: $0.byteCount,
                sha256: $0.sha256
            )
        },
        archiveSHA256: "fc1d81921cc4b2618e441b7b9d08c4bcb5cff90731be1bfa6f3a7b054fc0cb54",
        levelSHA256: "915a561cd3bd720d88bffed72fe41b4ff711c287711f060ecd9696e2cd5f7d41",
        d3lvVersion: 127,
        archiveEntryName: levelEntry.sourceName,
        archiveEntryOffset: levelEntry.payloadRange.lowerBound,
        archiveEntryByteCount: levelData.count,
        referenceChecksum: "6db74a2eb0c563de4eb11e6d4e91e59c",
        referenceChecksumBasis: "pinned-source-provenance-implied-by-exact-level-sha256"
    )
    let level = try! parseD3LV127(levelData, source: source)

    try writeCanonicalPackage(level, to: arguments.staging)
    let stagedLevel = try loadCanonicalLevel(from: arguments.staging)
    precondition(stagedLevel == level)
    let contentData = try Data(
        contentsOf: arguments.staging.appending(path: "content.json"),
        options: .mappedIfSafe
    )
    let canonicalLevelData = try Data(
        contentsOf: arguments.staging
            .appending(path: "levels", directoryHint: .isDirectory)
            .appending(path: level.levelKey, directoryHint: .isDirectory)
            .appending(path: "level.json"),
        options: .mappedIfSafe
    )
    let report = makeD3ImportReport(
        level: level,
        scope: arguments.scope,
        archives: inventories,
        packageContentSHA256: canonicalSHA256(contentData),
        packageLevelSHA256: canonicalSHA256(canonicalLevelData)
    )
    let reportData = try! canonicalJSONData(report)
    try promoteCanonicalPackage(
        from: arguments.staging,
        to: arguments.destination,
        reportData: reportData,
        reportURL: arguments.report,
        cancellationCheck: cancellationCheck
    )
    return report
}

func validateD3ImportPaths(_ arguments: D3ImportArguments) throws {
    let source = arguments.source.resolvingSymlinksInPath().standardizedFileURL
    let staging = arguments.staging.resolvingSymlinksInPath().standardizedFileURL
    let destination = arguments.destination.resolvingSymlinksInPath().standardizedFileURL
    let report = arguments.report.resolvingSymlinksInPath().standardizedFileURL

    try requireSourceDirectory(arguments.source)
    try requireOutputDirectory(arguments.staging.deletingLastPathComponent())
    try requireOutputDirectory(arguments.destination.deletingLastPathComponent())
    try requireOutputDirectory(arguments.report.deletingLastPathComponent())

    guard !pathsAreEquivalent(staging, destination),
          pathsAreEquivalent(
              staging.deletingLastPathComponent(),
              destination.deletingLastPathComponent()
          ) else {
        throw D3ImportOperationError.stagingIsNotDestinationAdjacent
    }

    let packagePaths = [staging, destination]
    guard pathsAreEquivalent(
        report.deletingLastPathComponent(),
        destination.deletingLastPathComponent()
    ) else {
        throw D3ImportOperationError.invalidOutputPath
    }
    guard packagePaths.allSatisfy({ pathIsDisjoint($0, source) }),
          packagePaths.allSatisfy({ pathIsDisjoint($0, report) }) else {
        throw D3ImportOperationError.overlappingPaths
    }

    if FileManager.default.fileExists(atPath: arguments.report.path) {
        let values = try arguments.report.resourceValues(forKeys: [
            .isRegularFileKey,
            .isSymbolicLinkKey,
        ])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw D3ImportOperationError.invalidOutputPath
        }
    }
}

struct ValidatedPreparedRetailFile: Equatable, Sendable {
    let file: PreparedRetailFile
    let data: Data
}

func readValidatedPreparedRetailFile(
    _ file: PreparedRetailFile,
    at sourceURL: URL
) throws -> ValidatedPreparedRetailFile {
    try requireSourceDirectory(sourceURL)
    let components = file.relativePath.split(separator: "/", omittingEmptySubsequences: false)
    precondition(components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }))
    let fileName = components.last!

    let sourceRoot = sourceURL.resolvingSymlinksInPath().standardizedFileURL
    var parent = sourceRoot
    for component in components.dropLast() {
        parent.append(path: String(component), directoryHint: .isDirectory)
        let values = try parent.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw D3ImportOperationError.invalidPreparedFile(file.relativePath)
        }
    }
    let url = parent.appending(path: String(fileName))
    let descriptor = open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
    guard descriptor >= 0 else {
        throw D3ImportOperationError.invalidPreparedFile(file.relativePath)
    }
    let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)

    var status = stat()
    guard fstat(descriptor, &status) == 0,
          status.st_mode & S_IFMT == S_IFREG else {
        throw D3ImportOperationError.invalidPreparedFile(file.relativePath)
    }
    guard status.st_size == file.byteCount else {
        throw D3ImportOperationError.preparedFileSizeMismatch(file.relativePath)
    }
    let data = try handle.readToEnd() ?? Data()
    guard data.count == file.byteCount else {
        throw D3ImportOperationError.preparedFileSizeMismatch(file.relativePath)
    }
    guard canonicalSHA256(data) == file.sha256 else {
        throw D3ImportOperationError.preparedFileDigestMismatch(file.relativePath)
    }
    return ValidatedPreparedRetailFile(file: file, data: data)
}

func promoteCanonicalPackage(
    from stagingURL: URL,
    to destinationURL: URL,
    reportData: Data,
    reportURL: URL,
    cancellationCheck: D3ImportCancellationCheck
) throws {
    let packageDirectory = open(
        stagingURL.deletingLastPathComponent().path,
        O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
    )
    guard packageDirectory >= 0 else {
        throw D3ImportOperationError.invalidOutputDirectory
    }
    defer { close(packageDirectory) }
    guard flock(packageDirectory, LOCK_EX) == 0 else {
        throw D3ImportOperationError.promotionLockFailed(errno)
    }
    try throwIfD3ImportCancelled(cancellationCheck)

    let hadDestination = FileManager.default.fileExists(atPath: destinationURL.path)
    if hadDestination {
        _ = try loadCanonicalLevel(from: destinationURL)
    }

    let hadReport = FileManager.default.fileExists(atPath: reportURL.path)
    let reportCandidate = reportURL.deletingLastPathComponent().appending(
        path: ".\(reportURL.lastPathComponent).\(UUID().uuidString).candidate"
    )
    try reportData.write(to: reportCandidate)

    let reportFlags = hadReport
        ? UInt32(RENAME_SWAP | RENAME_NOFOLLOW_ANY | RENAME_RESOLVE_BENEATH)
        : UInt32(RENAME_EXCL | RENAME_NOFOLLOW_ANY | RENAME_RESOLVE_BENEATH)
    if renameatx_np(
        packageDirectory,
        reportCandidate.lastPathComponent,
        packageDirectory,
        reportURL.lastPathComponent,
        reportFlags
    ) != 0 {
        removePromotionArtifact(reportCandidate)
        throw D3ImportOperationError.reportPromotionFailed
    }

    do {
        try throwIfD3ImportCancelled(cancellationCheck)
        let packageFlags = hadDestination
            ? UInt32(RENAME_SWAP | RENAME_NOFOLLOW_ANY | RENAME_RESOLVE_BENEATH)
            : UInt32(RENAME_EXCL | RENAME_NOFOLLOW_ANY | RENAME_RESOLVE_BENEATH)
        guard renameatx_np(
            packageDirectory,
            stagingURL.lastPathComponent,
            packageDirectory,
            destinationURL.lastPathComponent,
            packageFlags
        ) == 0 else {
            throw D3ImportOperationError.packagePromotionFailed
        }
    } catch {
        let rollbackSource = hadReport ? reportCandidate.lastPathComponent : reportURL.lastPathComponent
        let rollbackTarget = hadReport ? reportURL.lastPathComponent : reportCandidate.lastPathComponent
        let rollbackFlags = hadReport
            ? UInt32(RENAME_SWAP | RENAME_NOFOLLOW_ANY | RENAME_RESOLVE_BENEATH)
            : UInt32(RENAME_EXCL | RENAME_NOFOLLOW_ANY | RENAME_RESOLVE_BENEATH)
        guard renameatx_np(
            packageDirectory,
            rollbackSource,
            packageDirectory,
            rollbackTarget,
            rollbackFlags
        ) == 0 else {
            throw D3ImportOperationError.reportRollbackFailed(errno)
        }
        removePromotionArtifact(reportCandidate)
        throw error
    }

    if hadDestination { removePromotionArtifact(stagingURL) }
    if hadReport { removePromotionArtifact(reportCandidate) }
}

private func throwIfD3ImportCancelled(_ check: D3ImportCancellationCheck) throws {
    if let signal = check() {
        throw D3ImportOperationError.cancelled(signal)
    }
}

private func removePromotionArtifact(_ url: URL) {
    do {
        try FileManager.default.removeItem(at: url)
    } catch {
        fputs(
            "D3Import: warning: retained promotion artifact \(url.lastPathComponent): \(error)\n",
            stderr
        )
    }
}

struct D3ImportArguments: Equatable, Sendable {
    let contract: Int
    let source: URL
    let staging: URL
    let destination: URL
    let scope: String
    let report: URL

    static func parse(_ arguments: [String]) throws -> D3ImportArguments {
        let allowedFlags = Set([
            "--contract", "--source", "--staging", "--destination", "--scope", "--report",
        ])
        guard arguments.count == 13 else { throw D3ImportOperationError.invalidArguments }

        var values: [String: String] = [:]
        for index in stride(from: 1, to: arguments.count, by: 2) {
            let flag = arguments[index]
            guard allowedFlags.contains(flag), values[flag] == nil else {
                throw D3ImportOperationError.invalidArguments
            }
            values[flag] = arguments[index + 1]
        }
        guard values.count == allowedFlags.count,
              let contractText = values["--contract"],
              let contract = Int(contractText),
              contract == 1,
              let source = values["--source"], !source.isEmpty,
              let staging = values["--staging"], !staging.isEmpty,
              let destination = values["--destination"], !destination.isEmpty,
              let scope = values["--scope"],
              [
                  "descent3.level.training-mission",
                  "descent3.mission.pilot-training",
              ].contains(scope),
              let report = values["--report"], !report.isEmpty else {
            throw D3ImportOperationError.invalidArguments
        }

        return D3ImportArguments(
            contract: contract,
            source: URL(fileURLWithPath: source).standardizedFileURL,
            staging: URL(fileURLWithPath: staging).standardizedFileURL,
            destination: URL(fileURLWithPath: destination).standardizedFileURL,
            scope: scope,
            report: URL(fileURLWithPath: report).standardizedFileURL
        )
    }
}

enum D3ImportOperationError: Error, Equatable {
    case invalidArguments
    case invalidSourceDirectory
    case invalidPreparedFile(String)
    case preparedFileSizeMismatch(String)
    case preparedFileDigestMismatch(String)
    case stagingIsNotDestinationAdjacent
    case overlappingPaths
    case invalidOutputDirectory
    case invalidOutputPath
    case cancelled(Int32)
    case packagePromotionFailed
    case reportPromotionFailed
    case reportRollbackFailed(Int32)
    case promotionLockFailed(Int32)
}

private func requireOutputDirectory(_ url: URL) throws {
    let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
    guard values.isDirectory == true, values.isSymbolicLink != true else {
        throw D3ImportOperationError.invalidOutputDirectory
    }
}

private func requireSourceDirectory(_ url: URL) throws {
    let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
    guard values.isDirectory == true, values.isSymbolicLink != true else {
        throw D3ImportOperationError.invalidSourceDirectory
    }
}

private func pathIsDisjoint(_ first: URL, _ second: URL) -> Bool {
    !pathIsAncestorOrEqual(first, second) && !pathIsAncestorOrEqual(second, first)
}

private func pathIsAncestorOrEqual(_ ancestor: URL, _ descendant: URL) -> Bool {
    let ancestorComponents = ancestor.pathComponents
    let descendantComponents = descendant.pathComponents
    guard ancestorComponents.count <= descendantComponents.count else { return false }
    return zip(ancestorComponents, descendantComponents).allSatisfy {
        $0.caseInsensitiveCompare($1) == .orderedSame
    }
}

private func pathsAreEquivalent(_ first: URL, _ second: URL) -> Bool {
    let firstComponents = first.pathComponents
    let secondComponents = second.pathComponents
    guard firstComponents.count == secondComponents.count else { return false }
    return zip(firstComponents, secondComponents).allSatisfy {
        $0.caseInsensitiveCompare($1) == .orderedSame
    }
}
