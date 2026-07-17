// SPDX-License-Identifier: GPL-3.0-or-later

import CryptoKit
import Foundation

private let canonicalContentName = "content.json"
private let canonicalLevelsName = "levels"
private let canonicalLevelName = "level.json"
private let maximumContentByteCount = 16 * 1_024 * 1_024
private let maximumLevelByteCount = 64 * 1_024 * 1_024
private let canonicalDeferredCoverage = [
    "behavior-execution",
    "matcen-production",
    "presentation-payload-preparation",
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

func writeCanonicalPackage(_ level: Level, to packageURL: URL) throws {
    guard !FileManager.default.fileExists(atPath: packageURL.path) else {
        throw CanonicalPackageError.destinationExists
    }

    let levelDirectoryName = try! canonicalLevelDirectoryName(level.levelKey)
    let levelRelativePath = "\(canonicalLevelsName)/\(levelDirectoryName)/\(canonicalLevelName)"
    let levelData = try! canonicalJSONEncoder().encode(level)
    let manifest = CanonicalPackageManifest(
        packageSchemaVersion: 1,
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
        translatedFeatureCoverage: ["complete-level-topology"],
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
    return level
}

func canonicalJSONData<T: Encodable>(_ value: T) throws -> Data {
    try canonicalJSONEncoder().encode(value)
}

func canonicalSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

enum CanonicalPackageError: Error, Equatable {
    case destinationExists
    case invalidPackageDirectory
    case unexpectedPackageContents
    case unsupportedManifest
    case invalidContentKey(String)
    case invalidMetadata(String)
    case notRegularFile(String)
    case fileTooLarge(String)
    case levelDigestMismatch
    case identityMismatch
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
    guard manifest.packageSchemaVersion == 1,
          manifest.importerContractVersion == 1,
          !manifest.profileIdentifier.isEmpty,
          !manifest.acceptedSourceFiles.isEmpty,
          manifest.translatedFeatureCoverage == ["complete-level-topology"],
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
