// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

private let currentPlayerSaveSchemaVersion = 1
private let requiredPlayerContinuationSchemaVersion = 7
private let maximumPlayerSaveByteCount = 8 * 1_024 * 1_024
private let playerQuicksaveName = "quicksave.json"

struct PlayerSaveEnvelope: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let profileID: UUID
    let package: CanonicalPackageReference
    let continuation: PlayerSimulationContinuation

    init(
        profileID: UUID,
        package: CanonicalPackageReference,
        continuation: PlayerSimulationContinuation
    ) {
        schemaVersion = currentPlayerSaveSchemaVersion
        self.profileID = profileID
        self.package = package
        self.continuation = continuation
    }
}

enum PlayerSaveError: Error, Equatable, LocalizedError {
    case missingSave
    case malformedSave
    case unsupportedSaveSchema(Int)
    case profileMismatch
    case packageMismatch
    case nonRegularFile
    case tooLarge
    case invalidContinuation
    case readFailed(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingSave:
            "No quicksave exists for the selected pilot."
        case .malformedSave:
            "The quicksave is corrupt."
        case let .unsupportedSaveSchema(version):
            "The quicksave uses unsupported save schema \(version)."
        case .profileMismatch:
            "The quicksave belongs to a different pilot."
        case .packageMismatch:
            "The quicksave belongs to a different canonical package."
        case .nonRegularFile:
            "The quicksave is not a regular owned file."
        case .tooLarge:
            "The quicksave is larger than 8 MiB."
        case .invalidContinuation:
            "The quicksave contains invalid player state."
        case let .readFailed(message):
            "Could not read the quicksave: \(message)"
        case let .writeFailed(message):
            "Could not write the quicksave: \(message)"
        }
    }
}

struct PlayerSaveFile: Sendable {
    let rootURL: URL

    static let revivalMac = Self(
        rootURL: URL.applicationSupportDirectory
            .appending(path: "Descent3Revival", directoryHint: .isDirectory)
            .appending(path: "RevivalMac", directoryHint: .isDirectory)
            .appending(path: "Saves", directoryHint: .isDirectory)
    )

    init(rootURL: URL) {
        self.rootURL = rootURL.standardizedFileURL
    }

    func quicksaveURL(profileID: UUID) -> URL {
        rootURL
            .appending(
                path: profileID.uuidString.lowercased(),
                directoryHint: .isDirectory
            )
            .appending(path: playerQuicksaveName)
    }

    func save(
        profileID: UUID,
        package: CanonicalPackageReference,
        continuation: PlayerSimulationContinuation
    ) throws {
        do {
            try package.validate()
        } catch {
            throw PlayerSaveError.packageMismatch
        }
        guard continuation.schemaVersion
                == requiredPlayerContinuationSchemaVersion,
              continuation.levelKey == package.levelKey,
              continuation.authoritativeRandomState != nil else {
            throw PlayerSaveError.invalidContinuation
        }

        let profileURL = profileDirectoryURL(profileID: profileID)
        let saveURL = quicksaveURL(profileID: profileID)
        do {
            try ensureOwnedDirectory(rootURL, createIntermediates: true)
            try ensureOwnedDirectory(profileURL, createIntermediates: false)
            if FileManager.default.fileExists(atPath: saveURL.path) {
                try requireRegularSaveFile(saveURL)
            }
            let data = try canonicalJSONData(PlayerSaveEnvelope(
                profileID: profileID,
                package: package,
                continuation: continuation
            ))
            guard data.count <= maximumPlayerSaveByteCount else {
                throw PlayerSaveError.tooLarge
            }
            try data.write(to: saveURL, options: .atomic)
        } catch let error as PlayerSaveError {
            throw error
        } catch {
            throw PlayerSaveError.writeFailed(error.localizedDescription)
        }
    }

    func load(
        profileID: UUID,
        package: CanonicalPackageReference,
        baseLevel: Level,
        resumedAtTimestamp: Double
    ) throws -> PlayerSimulation {
        let profileURL = profileDirectoryURL(profileID: profileID)
        let saveURL = quicksaveURL(profileID: profileID)
        guard FileManager.default.fileExists(atPath: saveURL.path) else {
            throw PlayerSaveError.missingSave
        }
        do {
            try requireOwnedDirectory(rootURL)
            try requireOwnedDirectory(profileURL)
            try requireRegularSaveFile(saveURL)
        } catch let error as PlayerSaveError {
            throw error
        } catch {
            throw PlayerSaveError.readFailed(error.localizedDescription)
        }

        let data: Data
        do {
            data = try Data(contentsOf: saveURL)
        } catch {
            throw PlayerSaveError.readFailed(error.localizedDescription)
        }
        guard data.count <= maximumPlayerSaveByteCount else {
            throw PlayerSaveError.tooLarge
        }
        struct SchemaHeader: Decodable {
            let schemaVersion: Int
        }
        let decoder = JSONDecoder()
        let header: SchemaHeader
        do {
            header = try decoder.decode(SchemaHeader.self, from: data)
        } catch {
            throw PlayerSaveError.malformedSave
        }
        guard header.schemaVersion == currentPlayerSaveSchemaVersion else {
            throw PlayerSaveError.unsupportedSaveSchema(header.schemaVersion)
        }

        let envelope: PlayerSaveEnvelope
        do {
            envelope = try decoder.decode(PlayerSaveEnvelope.self, from: data)
            try envelope.package.validate()
        } catch {
            throw PlayerSaveError.malformedSave
        }
        guard envelope.profileID == profileID else {
            throw PlayerSaveError.profileMismatch
        }
        guard envelope.package == package else {
            throw PlayerSaveError.packageMismatch
        }
        guard envelope.continuation.schemaVersion
                == requiredPlayerContinuationSchemaVersion,
              envelope.continuation.levelKey == package.levelKey,
              envelope.continuation.authoritativeRandomState != nil,
              baseLevel.levelKey == package.levelKey,
              resumedAtTimestamp.isFinite else {
            throw PlayerSaveError.invalidContinuation
        }
        do {
            return try PlayerSimulation(
                level: baseLevel,
                continuation: envelope.continuation,
                resumedAtTimestamp: resumedAtTimestamp
            )
        } catch {
            throw PlayerSaveError.invalidContinuation
        }
    }

    private func profileDirectoryURL(profileID: UUID) -> URL {
        rootURL.appending(
            path: profileID.uuidString.lowercased(),
            directoryHint: .isDirectory
        )
    }

    private func ensureOwnedDirectory(
        _ url: URL,
        createIntermediates: Bool
    ) throws {
        do {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: createIntermediates
            )
            try requireOwnedDirectory(url)
        } catch let error as PlayerSaveError {
            throw error
        } catch {
            throw PlayerSaveError.writeFailed(error.localizedDescription)
        }
    }

    private func requireOwnedDirectory(_ url: URL) throws {
        let values = try url.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard values.isDirectory == true,
              values.isSymbolicLink != true else {
            throw PlayerSaveError.nonRegularFile
        }
    }

    private func requireRegularSaveFile(_ url: URL) throws {
        let values = try url.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        )
        guard values.isRegularFile == true,
              values.isSymbolicLink != true,
              let byteCount = values.fileSize else {
            throw PlayerSaveError.nonRegularFile
        }
        guard byteCount <= maximumPlayerSaveByteCount else {
            throw PlayerSaveError.tooLarge
        }
    }
}
