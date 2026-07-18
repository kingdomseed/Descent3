// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum RevivalProjectError: Error, Equatable, LocalizedError {
    case unsupportedSchema(Int)
    case baseIdentityMismatch
    case roomMissing(Int)
    case invalidRoomNameEdit(Int)
    case invalidRoomName
    case roomNameTooLong
    case unchangedRoomName
    case duplicateRoomName(String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedSchema(version):
            "Revival project schema \(version) is not supported."
        case .baseIdentityMismatch:
            "The project base reference does not match the complete canonical level."
        case let .roomMissing(sourceIndex):
            "Source room \(sourceIndex) is missing from the complete project level."
        case let .invalidRoomNameEdit(sourceIndex):
            "The project contains an invalid or redundant name edit for source room \(sourceIndex)."
        case .invalidRoomName:
            "Room names cannot contain only whitespace or surrounding whitespace."
        case .roomNameTooLong:
            "Room names must use at most 19 UTF-8 bytes."
        case .unchangedRoomName:
            "The selected room already has that name."
        case let .duplicateRoomName(name):
            "A room named ‘\(name)’ already exists. Room names are compared without case."
        }
    }
}

struct RevivalPlaySession: Equatable, Sendable {
    let level: Level
    let selectedRoomSourceIndex: Int
    var camera: RoomCamera
}

struct RevivalRoomNameEdit: Codable, Equatable, Sendable {
    let sourceIndex: Int
    let name: String?
}

struct RevivalProjectSource: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let base: CanonicalPackageReference
    var roomNameEdits: [RevivalRoomNameEdit]

    init(base: CanonicalPackageReference) {
        schemaVersion = 1
        self.base = base
        roomNameEdits = []
    }
}

struct RevivalProject: Equatable, Sendable {
    private(set) var source: RevivalProjectSource
    private let importedBase: Level
    private(set) var level: Level

    var baseReference: CanonicalPackageReference { source.base }
    var persistedSource: RevivalProjectSource { source }

    init(activatedBase: ActivatedCanonicalPackage) throws {
        let importedBase = activatedBase.level
        let baseReference = activatedBase.reference
        source = RevivalProjectSource(base: baseReference)
        self.importedBase = importedBase
        level = importedBase
        try validate()
    }

    init(
        source: RevivalProjectSource,
        library: CanonicalPackageLibrary
    ) throws {
        guard source.schemaVersion == 1 else {
            throw RevivalProjectError.unsupportedSchema(source.schemaVersion)
        }
        let importedBase = try library.load(source.base)

        var previousSourceIndex: Int?
        var materializedLevel = importedBase
        for edit in source.roomNameEdits {
            guard previousSourceIndex.map({ $0 < edit.sourceIndex }) ?? true,
                  let roomIndex = materializedLevel.rooms.firstIndex(where: {
                      $0.sourceIndex == edit.sourceIndex
                  }),
                  let baseRoom = importedBase.rooms.first(where: {
                      $0.sourceIndex == edit.sourceIndex
                  }),
                  baseRoom.name != edit.name else {
                throw RevivalProjectError.invalidRoomNameEdit(edit.sourceIndex)
            }
            try validateRoomName(edit.name)
            materializedLevel.rooms[roomIndex].name = edit.name
            previousSourceIndex = edit.sourceIndex
        }

        self.source = source
        self.importedBase = importedBase
        level = materializedLevel
        try validate()
    }

    @discardableResult
    mutating func renameRoom(
        sourceIndex: Int,
        to proposedName: String
    ) throws -> String? {
        guard let roomIndex = level.rooms.firstIndex(where: {
            $0.sourceIndex == sourceIndex
        }) else {
            throw RevivalProjectError.roomMissing(sourceIndex)
        }

        let trimmedName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmedName.isEmpty ? nil : trimmedName
        try validateRoomName(name)
        let previousName = level.rooms[roomIndex].name
        guard previousName != name else {
            throw RevivalProjectError.unchangedRoomName
        }
        if let name, level.rooms.enumerated().contains(where: { index, room in
            index != roomIndex && room.name?.caseInsensitiveCompare(name) == .orderedSame
        }) {
            throw RevivalProjectError.duplicateRoomName(name.lowercased())
        }

        level.rooms[roomIndex].name = name
        updateRoomNameEdit(sourceIndex: sourceIndex)
        return previousName
    }

    func validate() throws {
        guard source.schemaVersion == 1 else {
            throw RevivalProjectError.unsupportedSchema(source.schemaVersion)
        }
        guard importedBase.missionKey == source.base.missionKey,
              importedBase.levelKey == source.base.levelKey,
              level.missionKey == source.base.missionKey,
              level.levelKey == source.base.levelKey else {
            throw RevivalProjectError.baseIdentityMismatch
        }

        var roomNames: [String] = []
        for room in level.rooms {
            guard let name = room.name else { continue }
            try validateRoomName(name)
            guard !roomNames.contains(where: {
                $0.caseInsensitiveCompare(name) == .orderedSame
            }) else {
                throw RevivalProjectError.duplicateRoomName(name.lowercased())
            }
            roomNames.append(name)
        }

        var expectedEdits: [RevivalRoomNameEdit] = []
        for room in level.rooms {
            guard let baseRoom = importedBase.rooms.first(where: {
                $0.sourceIndex == room.sourceIndex
            }) else {
                throw RevivalProjectError.roomMissing(room.sourceIndex)
            }
            if baseRoom.name != room.name {
                expectedEdits.append(.init(sourceIndex: room.sourceIndex, name: room.name))
            }
        }
        expectedEdits.sort { $0.sourceIndex < $1.sourceIndex }
        guard source.roomNameEdits == expectedEdits else {
            let sourceIndex = source.roomNameEdits.first?.sourceIndex
                ?? expectedEdits.first?.sourceIndex
                ?? -1
            throw RevivalProjectError.invalidRoomNameEdit(sourceIndex)
        }
    }

    @discardableResult
    mutating func restoreRoomName(
        sourceIndex: Int,
        to name: String?
    ) throws -> String? {
        guard let roomIndex = level.rooms.firstIndex(where: {
            $0.sourceIndex == sourceIndex
        }) else {
            throw RevivalProjectError.roomMissing(sourceIndex)
        }

        let previousName = level.rooms[roomIndex].name
        try validateRoomName(name)
        level.rooms[roomIndex].name = name
        updateRoomNameEdit(sourceIndex: sourceIndex)
        return previousName
    }

    func makePlaySession(
        selectedRoomSourceIndex: Int,
        camera: RoomCamera
    ) throws -> RevivalPlaySession {
        guard level.rooms.contains(where: {
            $0.sourceIndex == selectedRoomSourceIndex
        }) else {
            throw RevivalProjectError.roomMissing(selectedRoomSourceIndex)
        }

        return RevivalPlaySession(
            level: level,
            selectedRoomSourceIndex: selectedRoomSourceIndex,
            camera: camera
        )
    }

    private mutating func updateRoomNameEdit(sourceIndex: Int) {
        let baseName = importedBase.rooms.first {
            $0.sourceIndex == sourceIndex
        }!.name
        let currentName = level.rooms.first {
            $0.sourceIndex == sourceIndex
        }!.name
        source.roomNameEdits.removeAll { $0.sourceIndex == sourceIndex }
        if baseName != currentName {
            source.roomNameEdits.append(.init(sourceIndex: sourceIndex, name: currentName))
            source.roomNameEdits.sort { $0.sourceIndex < $1.sourceIndex }
        }
    }
}

private func validateRoomName(_ name: String?) throws {
    guard let name else { return }
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty, trimmedName == name else {
        throw RevivalProjectError.invalidRoomName
    }
    guard name.utf8.count <= 19 else {
        throw RevivalProjectError.roomNameTooLong
    }
}
