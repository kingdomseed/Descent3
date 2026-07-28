// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

private let pilotProfileRecordName = "profiles.json"
private let maximumPilotProfileRecordByteCount = 1_024 * 1_024
private let currentPilotProfileSchemaVersion = 1
private let pilotTrainingMissionName = "Pilot Training"
private let pilotTrainingMissionKey = "descent3.mission.pilot-training"
private let pilotTrainingLevelKey = "descent3.level.training-mission"
private let pilotTrainingDefaultShipPermissions = 0x01

struct PilotProfile: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let missionProgress: [PilotMissionProgress]
}

struct PilotMissionProgress: Codable, Equatable, Sendable {
    let missionName: String
    let package: CanonicalPackageReference
    let highestLevel: Int
    let finished: Bool
    let restoreCount: Int
    let saveCount: Int
    let shipPermissions: Int
}

struct PilotProfileLibraryRecord: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let defaultProfileID: UUID?
    let profiles: [PilotProfile]

    static let empty = Self(
        schemaVersion: currentPilotProfileSchemaVersion,
        defaultProfileID: nil,
        profiles: []
    )
}

enum PilotProfileLibraryError: LocalizedError, Equatable {
    case unsupportedSchema(Int)
    case malformedRecord
    case invalidName
    case duplicateName
    case unknownProfile
    case readFailed(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedSchema(version):
            "The pilot profile library uses unsupported schema \(version)."
        case .malformedRecord:
            "The pilot profile library is malformed."
        case .invalidName:
            "Pilot names must contain 1–19 UTF-8 bytes and no control characters."
        case .duplicateName:
            "A pilot with that name already exists."
        case .unknownProfile:
            "The selected pilot no longer exists."
        case let .readFailed(message):
            "Could not read pilot profiles: \(message)"
        case let .writeFailed(message):
            "Could not save pilot profiles: \(message)"
        }
    }
}

struct PilotProfileLibrary: Sendable {
    let rootURL: URL

    static let revivalMac = applicationSupportLibrary(component: "RevivalMac")
    static let revivalMobile = applicationSupportLibrary(
        component: "RevivalMobile"
    )

    init(rootURL: URL) {
        self.rootURL = rootURL.standardizedFileURL
    }

    func load() throws -> PilotProfileLibraryRecord {
        let recordURL = rootURL.appending(path: pilotProfileRecordName)
        guard FileManager.default.fileExists(atPath: recordURL.path) else {
            return .empty
        }

        let rootValues: URLResourceValues
        do {
            rootValues = try rootURL.resourceValues(
                forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
            )
        } catch {
            throw PilotProfileLibraryError.readFailed(
                error.localizedDescription
            )
        }
        guard rootValues.isDirectory == true,
              rootValues.isSymbolicLink != true else {
            throw PilotProfileLibraryError.malformedRecord
        }

        let values: URLResourceValues
        do {
            values = try recordURL.resourceValues(
                forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
            )
        } catch {
            throw PilotProfileLibraryError.readFailed(
                error.localizedDescription
            )
        }
        guard values.isRegularFile == true,
              values.isSymbolicLink != true,
              let byteCount = values.fileSize,
              byteCount <= maximumPilotProfileRecordByteCount else {
            throw PilotProfileLibraryError.malformedRecord
        }

        let data: Data
        do {
            data = try Data(contentsOf: recordURL)
        } catch {
            throw PilotProfileLibraryError.readFailed(
                error.localizedDescription
            )
        }

        struct SchemaHeader: Decodable {
            let schemaVersion: Int
        }
        let decoder = JSONDecoder()
        let header: SchemaHeader
        do {
            header = try decoder.decode(SchemaHeader.self, from: data)
        } catch {
            throw PilotProfileLibraryError.malformedRecord
        }
        guard header.schemaVersion == currentPilotProfileSchemaVersion else {
            throw PilotProfileLibraryError.unsupportedSchema(
                header.schemaVersion
            )
        }

        let record: PilotProfileLibraryRecord
        do {
            record = try decoder.decode(
                PilotProfileLibraryRecord.self,
                from: data
            )
        } catch {
            throw PilotProfileLibraryError.malformedRecord
        }
        try validate(record)
        return record
    }

    func createProfile(named proposedName: String) throws
        -> PilotProfileLibraryRecord
    {
        let record = try load()
        let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        try validate(name: name)
        guard !record.profiles.contains(where: {
            $0.name.caseInsensitiveCompare(name) == .orderedSame
        }) else {
            throw PilotProfileLibraryError.duplicateName
        }
        let updated = PilotProfileLibraryRecord(
            schemaVersion: currentPilotProfileSchemaVersion,
            defaultProfileID: record.defaultProfileID,
            profiles: record.profiles + [
                PilotProfile(id: UUID(), name: name, missionProgress: []),
            ]
        )
        try write(updated)
        return updated
    }

    func confirmProfile(_ profileID: UUID) throws
        -> PilotProfileLibraryRecord
    {
        let record = try load()
        guard record.profiles.contains(where: { $0.id == profileID }) else {
            throw PilotProfileLibraryError.unknownProfile
        }
        let updated = PilotProfileLibraryRecord(
            schemaVersion: currentPilotProfileSchemaVersion,
            defaultProfileID: profileID,
            profiles: record.profiles
        )
        try write(updated)
        return updated
    }

    func recordTrainingCompletion(
        profileID: UUID,
        package: CanonicalPackageReference
    ) throws -> PilotProfileLibraryRecord {
        try package.validate()
        guard package.missionKey == pilotTrainingMissionKey,
              package.levelKey == pilotTrainingLevelKey else {
            throw PilotProfileLibraryError.malformedRecord
        }
        let record = try load()
        guard let profileIndex = record.profiles.firstIndex(where: {
            $0.id == profileID
        }) else {
            throw PilotProfileLibraryError.unknownProfile
        }

        var profiles = record.profiles
        let profile = profiles[profileIndex]
        let progress = PilotMissionProgress(
            missionName: pilotTrainingMissionName,
            package: package,
            highestLevel: 0,
            finished: true,
            restoreCount: 0,
            saveCount: 0,
            shipPermissions: pilotTrainingDefaultShipPermissions
        )
        var missionProgress = profile.missionProgress.filter {
            $0.missionName.caseInsensitiveCompare(pilotTrainingMissionName)
                != .orderedSame
        }
        missionProgress.append(progress)
        profiles[profileIndex] = PilotProfile(
            id: profile.id,
            name: profile.name,
            missionProgress: missionProgress
        )
        let updated = PilotProfileLibraryRecord(
            schemaVersion: currentPilotProfileSchemaVersion,
            defaultProfileID: record.defaultProfileID,
            profiles: profiles
        )
        try write(updated)
        return updated
    }

    private func write(_ record: PilotProfileLibraryRecord) throws {
        try validate(record)
        do {
            try ensureOwnedDirectory()
            try canonicalJSONData(record).write(
                to: rootURL.appending(path: pilotProfileRecordName),
                options: .atomic
            )
        } catch let error as PilotProfileLibraryError {
            throw error
        } catch {
            throw PilotProfileLibraryError.writeFailed(
                error.localizedDescription
            )
        }
    }

    private func ensureOwnedDirectory() throws {
        do {
            try FileManager.default.createDirectory(
                at: rootURL,
                withIntermediateDirectories: true
            )
            let values = try rootURL.resourceValues(
                forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
            )
            guard values.isDirectory == true, values.isSymbolicLink != true else {
                throw PilotProfileLibraryError.writeFailed(
                    "The profile location is not an owned directory."
                )
            }
        } catch let error as PilotProfileLibraryError {
            throw error
        } catch {
            throw PilotProfileLibraryError.writeFailed(
                error.localizedDescription
            )
        }
    }

    private func validate(_ record: PilotProfileLibraryRecord) throws {
        guard record.schemaVersion == currentPilotProfileSchemaVersion,
              Set(record.profiles.map(\.id)).count == record.profiles.count
        else {
            throw PilotProfileLibraryError.malformedRecord
        }
        var names: Set<String> = []
        for profile in record.profiles {
            try validate(name: profile.name)
            guard names.insert(profile.name.lowercased()).inserted else {
                throw PilotProfileLibraryError.malformedRecord
            }
            var missionNames: Set<String> = []
            for progress in profile.missionProgress {
                guard missionNames.insert(
                    progress.missionName.lowercased()
                ).inserted else {
                    throw PilotProfileLibraryError.malformedRecord
                }
                try validate(progress)
            }
        }
        if let defaultProfileID = record.defaultProfileID {
            guard record.profiles.contains(where: {
                $0.id == defaultProfileID
            }) else {
                throw PilotProfileLibraryError.malformedRecord
            }
        }
    }

    private func validate(_ progress: PilotMissionProgress) throws {
        do {
            try progress.package.validate()
        } catch {
            throw PilotProfileLibraryError.malformedRecord
        }
        guard progress.missionName == pilotTrainingMissionName,
              progress.package.missionKey == pilotTrainingMissionKey,
              progress.package.levelKey == pilotTrainingLevelKey,
              progress.highestLevel == 0,
              progress.finished,
              progress.restoreCount == 0,
              progress.saveCount == 0,
              progress.shipPermissions == pilotTrainingDefaultShipPermissions
        else {
            throw PilotProfileLibraryError.malformedRecord
        }
    }

    private func validate(name: String) throws {
        guard name == name.trimmingCharacters(in: .whitespacesAndNewlines),
              (1...19).contains(name.utf8.count),
              !name.unicodeScalars.contains(where: {
                  CharacterSet.controlCharacters.contains($0)
              }) else {
            throw PilotProfileLibraryError.invalidName
        }
    }

    private static func applicationSupportLibrary(component: String) -> Self {
        Self(
            rootURL: URL.applicationSupportDirectory
                .appending(path: "Descent3Revival", directoryHint: .isDirectory)
                .appending(path: component, directoryHint: .isDirectory)
                .appending(path: "Profiles", directoryHint: .isDirectory)
        )
    }
}
