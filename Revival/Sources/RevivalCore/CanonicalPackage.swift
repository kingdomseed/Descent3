// SPDX-License-Identifier: GPL-3.0-or-later

import CryptoKit
import Foundation

private let canonicalContentName = "content.json"
private let canonicalLevelsName = "levels"
private let canonicalLevelName = "level.json"
private let canonicalPackagesName = "packages"
private let canonicalActivePackageName = "active-base.json"
private let canonicalStagingPrefix = ".candidate-"
private let maximumContentByteCount = 16 * 1_024 * 1_024
private let maximumLevelByteCount = 64 * 1_024 * 1_024
private let maximumActivePackageByteCount = 64 * 1_024
private let canonicalDeferredCoverage = [
    "behavior-execution",
    "matcen-production",
    "volumetric-navigation-rebuild",
]

struct CanonicalRights: Codable, Equatable, Sendable {
    let classification: String
    let localOnly: Bool
    let redistributionAllowed: Bool
}

struct CanonicalCampaignCoverage: Codable, Equatable, Sendable {
    let missionKey: String
    let completeLevelKeys: [String]
}

struct CanonicalLevelManifest: Codable, Equatable, Sendable {
    let levelKey: String
    let relativePath: String
    let sha256: String
}

struct CanonicalPackageManifest: Codable, Equatable, Sendable {
    let packageSchemaVersion: Int
    let importerContractVersion: Int
    let profileIdentifier: String
    let acceptedSourceFiles: [SourceFileFingerprint]
    let campaigns: [CanonicalCampaignCoverage]
    let levels: [CanonicalLevelManifest]
    let translatedFeatureCoverage: [String]
    let deferredFeatureCoverage: [String]
    let source: LevelSource
    let sourceEntries: [SourceChunkRecord]
    let currentDependencies: [DependencyRecord]
    let rights: CanonicalRights
}

struct CanonicalPackageReference: Codable, Equatable, Sendable {
    let identitySHA256: String
    let missionKey: String
    let levelKey: String

    func validate() throws {
        guard isSHA256(identitySHA256),
              !missionKey.isEmpty,
              isSafeRelativePath(missionKey),
              !missionKey.contains("/"),
              try canonicalLevelDirectoryName(levelKey) == levelKey else {
            throw CanonicalPackageError.invalidMetadata("package reference")
        }
    }
}

private struct CanonicalActiveBaseRecord: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let base: CanonicalPackageReference

    init(base: CanonicalPackageReference) {
        schemaVersion = 1
        self.base = base
    }
}

struct ActivatedCanonicalPackage: Equatable, Sendable {
    let reference: CanonicalPackageReference
    let level: Level
    let installedPackageURL: URL

    fileprivate init(
        reference: CanonicalPackageReference,
        level: Level,
        installedPackageURL: URL
    ) {
        self.reference = reference
        self.level = level
        self.installedPackageURL = installedPackageURL
    }
}

struct CanonicalPackageRequestQueue<Request> {
    private var pending: [Request] = []
    private var isProcessing = false

    var isEmpty: Bool { pending.isEmpty }

    mutating func append(_ request: Request) {
        pending.append(request)
    }

    mutating func startNextIfIdle() -> Request? {
        guard !isProcessing, !pending.isEmpty else { return nil }
        isProcessing = true
        return pending.removeFirst()
    }

    mutating func finishCurrent() {
        precondition(isProcessing, "A canonical-package request must be active")
        isProcessing = false
    }

    mutating func removeAllPending() {
        pending.removeAll()
    }
}

/// The concrete native-package boundary shared by the player shells and editor.
/// It owns one directory of immutable package generations and
/// one atomically replaced active-base reference; package publication remains
/// D3Import's separate responsibility.
struct CanonicalPackageLibrary: Sendable {
    let rootURL: URL

    static let revivalMac = applicationSupportLibrary(component: "RevivalMac")
    static let revivalEditor = applicationSupportLibrary(component: "RevivalEditor")
    static let revivalMobile = applicationSupportLibrary(component: "RevivalMobile")

    var reimportableContentBackupExclusionURL: URL {
        rootURL
    }

    init(rootURL: URL) {
        self.rootURL = rootURL.standardizedFileURL
    }

    func prepareForUse() throws {
        try ensureLibraryDirectories()
        for name in try stagingArtifactNames() {
            try FileManager.default.removeItem(
                at: packagesDirectoryURL.appending(path: name)
            )
        }
    }

    func excludeReimportableContentFromBackup() throws {
        var contentURL = reimportableContentBackupExclusionURL
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try contentURL.setResourceValues(values)
    }

    func installAndActivate(from candidateURL: URL) throws -> ActivatedCanonicalPackage {
        try ensureLibraryDirectories()
        guard try stagingArtifactNames().isEmpty else {
            throw CanonicalPackageError.abandonedStagingRequiresRecovery
        }

        let stagingURL = packagesDirectoryURL.appending(
            path: "\(canonicalStagingPrefix)\(UUID().uuidString).revival",
            directoryHint: .isDirectory
        )
        var promoted = false
        defer {
            // A failed best-effort cleanup remains recognizable and is removed
            // by prepareForUse on the next application launch.
            if !promoted, FileManager.default.fileExists(atPath: stagingURL.path) {
                try? FileManager.default.removeItem(at: stagingURL)
            }
        }

        try FileManager.default.copyItem(at: candidateURL, to: stagingURL)
        let stagedPackage = try validateCanonicalPackage(from: stagingURL)
        let reference = stagedPackage.reference
        let installedURL = installedPackageURL(for: reference)

        if FileManager.default.fileExists(atPath: installedURL.path) {
            _ = try load(reference)
            throw CanonicalPackageError.duplicatePackageIdentity(
                reference.identitySHA256
            )
        } else {
            try FileManager.default.moveItem(at: stagingURL, to: installedURL)
            promoted = true
        }

        let installedLevel = try load(reference)
        try activate(reference)
        return ActivatedCanonicalPackage(
            reference: reference,
            level: installedLevel,
            installedPackageURL: installedURL
        )
    }

    private func ensureLibraryDirectories() throws {
        try ensureOwnedDirectory(rootURL, createIntermediateDirectories: true)
        let packagesURL = packagesDirectoryURL
        try ensureOwnedDirectory(packagesURL, createIntermediateDirectories: false)
    }

    private func stagingArtifactNames() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: packagesDirectoryURL.path)
            .filter {
                $0.hasPrefix(canonicalStagingPrefix) && $0.hasSuffix(".revival")
            }
    }

    func load(_ reference: CanonicalPackageReference) throws -> Level {
        try reference.validate()
        try requireCanonicalDirectory(rootURL)
        try requireCanonicalDirectory(packagesDirectoryURL)

        let packageURL = installedPackageURL(for: reference)
        let package = try validateCanonicalPackage(from: packageURL)
        guard package.reference == reference else {
            throw CanonicalPackageError.identityMismatch
        }
        return package.level
    }

    func loadInstalledPackage(
        matching candidateURL: URL
    ) throws -> ActivatedCanonicalPackage {
        let candidate = try validateCanonicalPackage(from: candidateURL)
        let reference = candidate.reference
        return ActivatedCanonicalPackage(
            reference: reference,
            level: try load(reference),
            installedPackageURL: installedPackageURL(for: reference)
        )
    }

    func loadActive() throws -> ActivatedCanonicalPackage? {
        try ensureLibraryDirectories()
        let activeURL = rootURL.appending(path: canonicalActivePackageName)
        guard FileManager.default.fileExists(atPath: activeURL.path) else {
            return nil
        }
        try requireCanonicalRegularFile(
            activeURL,
            maximumByteCount: maximumActivePackageByteCount
        )
        let record = try JSONDecoder().decode(
            CanonicalActiveBaseRecord.self,
            from: Data(contentsOf: activeURL)
        )
        guard record.schemaVersion == 1 else {
            throw CanonicalPackageError.unsupportedManifest
        }
        let reference = record.base
        let level = try load(reference)
        return ActivatedCanonicalPackage(
            reference: reference,
            level: level,
            installedPackageURL: installedPackageURL(for: reference)
        )
    }

    private var packagesDirectoryURL: URL {
        rootURL.appending(path: canonicalPackagesName, directoryHint: .isDirectory)
    }

    private func installedPackageURL(for reference: CanonicalPackageReference) -> URL {
        packagesDirectoryURL.appending(
            path: "\(reference.identitySHA256).revival",
            directoryHint: .isDirectory
        )
    }

    private func activate(_ reference: CanonicalPackageReference) throws {
        try reference.validate()
        let activeURL = rootURL.appending(path: canonicalActivePackageName)
        if FileManager.default.fileExists(atPath: activeURL.path) {
            try requireCanonicalRegularFile(
                activeURL,
                maximumByteCount: maximumActivePackageByteCount
            )
        }
        try canonicalJSONData(CanonicalActiveBaseRecord(base: reference)).write(
            to: activeURL,
            options: .atomic
        )
    }

    private static func applicationSupportLibrary(component: String) -> Self {
        return Self(
            rootURL: URL.applicationSupportDirectory
                .appending(path: "Descent3Revival", directoryHint: .isDirectory)
                .appending(path: component, directoryHint: .isDirectory)
                .appending(path: "Content", directoryHint: .isDirectory)
        )
    }
}

func writeCanonicalPackage(_ level: Level, to packageURL: URL) throws {
    try level.validate()
    guard level.hasSelectedRoomPresentation else {
        throw LevelValidationError.invalidDependency("missing canonical presentation")
    }
    guard !FileManager.default.fileExists(atPath: packageURL.path) else {
        throw CanonicalPackageError.destinationExists
    }

    let levelDirectoryName = try! canonicalLevelDirectoryName(level.levelKey)
    let levelRelativePath = "\(canonicalLevelsName)/\(levelDirectoryName)/\(canonicalLevelName)"
    let levelData = try! canonicalJSONEncoder().encode(level)
    let manifest = CanonicalPackageManifest(
        packageSchemaVersion: 2,
        importerContractVersion: 1,
        profileIdentifier: level.source.profileIdentifier,
        acceptedSourceFiles: level.source.profileFiles,
        campaigns: [
            .init(missionKey: level.missionKey, completeLevelKeys: [level.levelKey]),
        ],
        levels: [
            .init(
                levelKey: level.levelKey,
                relativePath: levelRelativePath,
                sha256: canonicalSHA256(levelData)
            ),
        ],
        translatedFeatureCoverage: canonicalTranslatedCoverage,
        deferredFeatureCoverage: canonicalDeferredCoverage,
        source: level.source,
        sourceEntries: level.sourceChunks,
        currentDependencies: level.dependencyManifest.current,
        rights: .init(
            classification: "user-owned-retail",
            localOnly: true,
            redistributionAllowed: false
        )
    )
    let manifestData = try! canonicalJSONEncoder().encode(manifest)

    let levelsURL = packageURL.appending(path: canonicalLevelsName, directoryHint: .isDirectory)
    let levelURL = levelsURL.appending(path: levelDirectoryName, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: false)
    try FileManager.default.createDirectory(at: levelsURL, withIntermediateDirectories: false)
    try FileManager.default.createDirectory(at: levelURL, withIntermediateDirectories: false)
    try levelData.write(to: levelURL.appending(path: canonicalLevelName))
    try manifestData.write(to: packageURL.appending(path: canonicalContentName))
}

func loadCanonicalLevel(from packageURL: URL) throws -> Level {
    try validateCanonicalPackage(from: packageURL).level
}

private struct ValidatedCanonicalPackage {
    let reference: CanonicalPackageReference
    let level: Level
}

private func validateCanonicalPackage(
    from packageURL: URL
) throws -> ValidatedCanonicalPackage {
    try requireCanonicalDirectory(packageURL)
    guard Set(try FileManager.default.contentsOfDirectory(atPath: packageURL.path))
        == [canonicalContentName, canonicalLevelsName] else {
        throw CanonicalPackageError.unexpectedPackageContents
    }

    let manifestURL = packageURL.appending(path: canonicalContentName)
    let levelsURL = packageURL.appending(path: canonicalLevelsName, directoryHint: .isDirectory)
    try requireCanonicalRegularFile(manifestURL, maximumByteCount: maximumContentByteCount)
    try requireCanonicalDirectory(levelsURL)

    let manifestData = try Data(contentsOf: manifestURL)
    let manifest = try JSONDecoder().decode(CanonicalPackageManifest.self, from: manifestData)
    try validateCanonicalManifest(manifest)
    guard manifest.levels.count == 1,
          manifest.campaigns.count == 1,
          let levelRecord = manifest.levels.first,
          let campaign = manifest.campaigns.first,
          campaign.completeLevelKeys == [levelRecord.levelKey] else {
        throw CanonicalPackageError.unsupportedManifest
    }

    let levelDirectoryName = try canonicalLevelDirectoryName(levelRecord.levelKey)
    let expectedRelativePath = "\(canonicalLevelsName)/\(levelDirectoryName)/\(canonicalLevelName)"
    guard levelRecord.relativePath == expectedRelativePath,
          Set(try FileManager.default.contentsOfDirectory(atPath: levelsURL.path)) == [levelDirectoryName] else {
        throw CanonicalPackageError.unexpectedPackageContents
    }

    let levelDirectoryURL = levelsURL.appending(path: levelDirectoryName, directoryHint: .isDirectory)
    try requireCanonicalDirectory(levelDirectoryURL)
    guard Set(try FileManager.default.contentsOfDirectory(atPath: levelDirectoryURL.path)) == [canonicalLevelName] else {
        throw CanonicalPackageError.unexpectedPackageContents
    }
    let levelURL = levelDirectoryURL.appending(path: canonicalLevelName)
    try requireCanonicalRegularFile(levelURL, maximumByteCount: maximumLevelByteCount)

    let levelData = try Data(contentsOf: levelURL)
    guard canonicalSHA256(levelData) == levelRecord.sha256 else {
        throw CanonicalPackageError.levelDigestMismatch
    }
    let level = try JSONDecoder().decode(Level.self, from: levelData)
    guard level.missionKey == campaign.missionKey,
          level.levelKey == levelRecord.levelKey,
          level.source == manifest.source,
          level.source.profileIdentifier == manifest.profileIdentifier,
          level.source.profileFiles == manifest.acceptedSourceFiles,
          level.sourceChunks == manifest.sourceEntries,
          level.dependencyManifest.current == manifest.currentDependencies else {
        throw CanonicalPackageError.identityMismatch
    }
    try level.validate()
    guard level.hasSelectedRoomPresentation else {
        throw CanonicalPackageError.identityMismatch
    }
    let reference = CanonicalPackageReference(
        identitySHA256: canonicalSHA256(try canonicalJSONData(manifest)),
        missionKey: level.missionKey,
        levelKey: level.levelKey
    )
    try reference.validate()
    return ValidatedCanonicalPackage(reference: reference, level: level)
}

func canonicalJSONData<T: Encodable>(_ value: T) throws -> Data {
    try canonicalJSONEncoder().encode(value)
}

func canonicalSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

enum CanonicalPackageError: Error, Equatable, LocalizedError {
    case destinationExists
    case duplicatePackageIdentity(String)
    case abandonedStagingRequiresRecovery
    case invalidPackageDirectory
    case unexpectedPackageContents
    case unsupportedManifest
    case invalidContentKey(String)
    case invalidMetadata(String)
    case notRegularFile(String)
    case fileTooLarge(String)
    case levelDigestMismatch
    case identityMismatch

    var errorDescription: String? {
        switch self {
        case .destinationExists:
            "A canonical package already exists at the requested destination."
        case let .duplicatePackageIdentity(identity):
            "Canonical package \(identity) is already installed."
        case .abandonedStagingRequiresRecovery:
            "An interrupted canonical-package install must be recovered before installing another package. Relaunch Revival and try again."
        case .invalidPackageDirectory:
            "The canonical package must be a real directory, not a link or special file."
        case .unexpectedPackageContents:
            "The canonical package contains missing or unexpected items."
        case .unsupportedManifest:
            "The canonical package manifest is unsupported or incomplete."
        case let .invalidContentKey(key):
            "The canonical content key ‘\(key)’ is invalid."
        case let .invalidMetadata(field):
            "The canonical package has invalid \(field) metadata."
        case let .notRegularFile(name):
            "The canonical package member ‘\(name)’ is not a regular file."
        case let .fileTooLarge(name):
            "The canonical package member ‘\(name)’ exceeds its size limit."
        case .levelDigestMismatch:
            "The canonical level does not match its declared SHA-256 digest."
        case .identityMismatch:
            "The canonical package and level identities do not agree."
        }
    }
}

private func canonicalJSONEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return encoder
}

private func canonicalLevelDirectoryName(_ key: String) throws -> String {
    let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
    guard !key.isEmpty,
          key != ".",
          key != "..",
          key.unicodeScalars.allSatisfy(allowed.contains) else {
        throw CanonicalPackageError.invalidContentKey(key)
    }
    return key
}

private func validateCanonicalManifest(_ manifest: CanonicalPackageManifest) throws {
    guard manifest.packageSchemaVersion == 2,
          manifest.importerContractVersion == 1,
          !manifest.profileIdentifier.isEmpty,
          !manifest.acceptedSourceFiles.isEmpty,
          manifest.translatedFeatureCoverage == canonicalTranslatedCoverage,
          manifest.deferredFeatureCoverage == canonicalDeferredCoverage,
          manifest.rights.classification == "user-owned-retail",
          manifest.rights.localOnly,
          !manifest.rights.redistributionAllowed else {
        throw CanonicalPackageError.unsupportedManifest
    }
    var paths = Set<String>()
    for sourceFile in manifest.acceptedSourceFiles {
        guard isSafeRelativePath(sourceFile.relativePath),
              sourceFile.byteCount >= 0,
              isSHA256(sourceFile.sha256),
              paths.insert(sourceFile.relativePath).inserted else {
            throw CanonicalPackageError.invalidMetadata("accepted source file")
        }
    }
    for level in manifest.levels {
        _ = try canonicalLevelDirectoryName(level.levelKey)
        guard isSafeRelativePath(level.relativePath), isSHA256(level.sha256) else {
            throw CanonicalPackageError.invalidMetadata("level")
        }
    }
}

private let canonicalTranslatedCoverage = [
    "complete-level-topology",
    "fixed-camera-portal-presentation",
]

private func isSafeRelativePath(_ path: String) -> Bool {
    let components = path.split(separator: "/", omittingEmptySubsequences: false)
    return !components.isEmpty
        && components.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
}

private func isSHA256(_ value: String) -> Bool {
    value.utf8.count == 64 && value.utf8.allSatisfy {
        ($0 >= 0x30 && $0 <= 0x39) || ($0 >= 0x61 && $0 <= 0x66)
    }
}

private func requireCanonicalDirectory(_ url: URL) throws {
    let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
    guard values.isDirectory == true, values.isSymbolicLink != true else {
        throw CanonicalPackageError.invalidPackageDirectory
    }
}

private func ensureOwnedDirectory(
    _ url: URL,
    createIntermediateDirectories: Bool
) throws {
    if FileManager.default.fileExists(atPath: url.path) {
        try requireCanonicalDirectory(url)
    } else {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: createIntermediateDirectories
        )
    }
}

private func requireCanonicalRegularFile(_ url: URL, maximumByteCount: Int) throws {
    let values = try url.resourceValues(forKeys: [
        .fileSizeKey,
        .isRegularFileKey,
        .isSymbolicLinkKey,
    ])
    guard values.isRegularFile == true, values.isSymbolicLink != true else {
        throw CanonicalPackageError.notRegularFile(url.lastPathComponent)
    }
    guard let fileSize = values.fileSize, fileSize <= maximumByteCount else {
        throw CanonicalPackageError.fileTooLarge(url.lastPathComponent)
    }
}
