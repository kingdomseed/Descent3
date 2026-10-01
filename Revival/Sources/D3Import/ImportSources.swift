// SPDX-License-Identifier: GPL-3.0-or-later
//
// The prepared retail files one import reads, opened in the order the game
// opens them. Source provenance:
// - cfile/cfile.cpp:264 cfopen: the most recently opened library is searched
//   first, so the mission library comes before the base libraries.
// - Descent3/Mission.cpp LoadMission: the mission library and its .msn
//   descriptor; LoadMissionLevel: the level's MINE file.
// - Descent3/LoadLevel.cpp: the level file the decoder reads
//   (D3LV127Decoder.swift).

import Foundation

/// One prepared library with its HOG2 directory.
struct PreparedLibrary {
    let file: PreparedRetailFile
    let data: Data
    let archive: HOG2Archive

    var relativePath: String { file.relativePath }

    func payload(_ entry: HOG2Entry) -> Data {
        data.subdata(in: entry.payloadRange)
    }
}

/// The libraries, tables, and level of one import.
struct ImportSources {
    let profile: PreparedRetailProfile
    /// Every prepared file of the profile, in profile order.
    let inventories: [PreparedArchiveInventory]
    /// The libraries in cfile search order: the mission library, then the
    /// base libraries.
    let searchOrder: [PreparedLibrary]
    let table: Data
    let overlay: Data
    let mission: PreparedRetailMission
    let descriptor: MissionDescriptor
    let level: PreparedRetailLevel
    /// The level's MINE name from the descriptor.
    let levelFileName: String
    let levelEntry: HOG2Entry
    let levelData: Data

    var missionLibrary: PreparedLibrary { searchOrder[0] }

    /// cfopen: the first library in search order with an entry of this
    /// name, with the entry and its index in that library.
    func firstEntry(
        named name: String
    ) -> (library: PreparedLibrary, entry: HOG2Entry, index: Int)? {
        for library in searchOrder {
            if let entry = library.archive.entry(named: name),
               let index = library.archive.entries.firstIndex(of: entry) {
                return (library, entry, index)
            }
        }
        return nil
    }

    /// The payload of the first entry with this name in search order.
    func payload(named name: String) -> Data? {
        firstEntry(named: name).map { $0.library.payload($0.entry) }
    }

    /// The libraries in search order, as the script data import reads them.
    var scriptArchives: [LevelScriptArchive] {
        searchOrder.map {
            .init(relativePath: $0.relativePath, data: $0.data, archive: $0.archive)
        }
    }

    /// The level's source identity: the profile, the mission library and
    /// level file digests, and the level entry's place in the library.
    var levelSource: LevelSource {
        LevelSource(
            profileIdentifier: profile.identifier,
            profileFiles: profile.files.map {
                SourceFileFingerprint(
                    relativePath: $0.relativePath,
                    byteCount: $0.byteCount,
                    sha256: $0.sha256
                )
            },
            archiveSHA256: missionLibrary.file.sha256,
            levelSHA256: canonicalSHA256(levelData),
            d3lvVersion: 127,
            archiveEntryName: levelEntry.sourceName,
            archiveEntryOffset: levelEntry.payloadRange.lowerBound,
            archiveEntryByteCount: levelData.count,
            referenceChecksum: level.referenceChecksum,
            referenceChecksumBasis: level.referenceChecksum.map { _ in
                "pinned-source-provenance-implied-by-exact-level-sha256"
            }
        )
    }

    var levelIdentity: D3LevelIdentity {
        .init(
            missionKey: mission.key,
            levelKey: level.key,
            historicalEagerBaseline: level.historicalEagerBaseline
        )
    }
}

enum ImportSourcesError: Error, Equatable {
    case unknownScope(String)
    case missingProfileFile(String)
    case missingEntry(archive: String, name: String)
    case invalidMission(String)
}

/// Reads and checks every prepared file of the profile, then opens the
/// mission the scope names and its level file.
func loadImportSources(
    _ arguments: D3ImportArguments,
    profile: PreparedRetailProfile = .training
) throws -> ImportSources {
    guard let (mission, levelIndex) = profile.importTarget(scope: arguments.scope)
    else {
        throw ImportSourcesError.unknownScope(arguments.scope)
    }
    var libraries: [String: PreparedLibrary] = [:]
    var inventories: [PreparedArchiveInventory] = []
    for file in profile.files {
        let validated = try readValidatedPreparedRetailFile(file, at: arguments.source)
        let archive = try parseHOG2(validated.data)
        libraries[file.relativePath] = .init(
            file: file,
            data: validated.data,
            archive: archive
        )
        inventories.append(.init(
            relativePath: file.relativePath,
            byteCount: file.byteCount,
            sha256: file.sha256,
            entryCount: archive.entries.count
        ))
    }
    func library(_ path: String) throws -> PreparedLibrary {
        guard let library = libraries[path] else {
            throw ImportSourcesError.missingProfileFile(path)
        }
        return library
    }
    func entry(_ name: String, in library: PreparedLibrary) throws -> HOG2Entry {
        guard let entry = library.archive.entry(named: name) else {
            throw ImportSourcesError.missingEntry(
                archive: library.relativePath,
                name: name
            )
        }
        return entry
    }
    let missionLibrary = try library(mission.archivePath)
    let searchOrder = try [missionLibrary]
        + profile.baseArchiveSearchOrder.map(library)
    let tableLibrary = try library(profile.tableArchive)
    let overlayLibrary = try library(profile.overlayArchive)
    let descriptor = try parseMissionDescriptor(
        missionLibrary.payload(try entry(mission.descriptorName, in: missionLibrary))
    )
    guard descriptor.levels.count == mission.levels.count else {
        throw ImportSourcesError.invalidMission(mission.key)
    }
    let levelFileName = descriptor.levels[levelIndex].mineSourceName
    let levelEntry = try entry(levelFileName, in: missionLibrary)
    return ImportSources(
        profile: profile,
        inventories: inventories,
        searchOrder: searchOrder,
        table: tableLibrary.payload(try entry(profile.tableName, in: tableLibrary)),
        overlay: overlayLibrary.payload(
            try entry(profile.overlayName, in: overlayLibrary)
        ),
        mission: mission,
        descriptor: descriptor,
        level: mission.levels[levelIndex],
        levelFileName: levelFileName,
        levelEntry: levelEntry,
        levelData: missionLibrary.payload(levelEntry)
    )
}
