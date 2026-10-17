// SPDX-License-Identifier: GPL-3.0-or-later
//
// Source provenance: Descent3/Mission.cpp mission declaration parsing
// (LoadMission's .msn keywords) and LoadMissionLevel's one-based level
// selection.

import Foundation

/// One LEVEL block of a mission descriptor.
struct MissionLevelDescriptor: Equatable, Sendable {
    let name: String
    let mineSourceName: String
}

/// A single-player mission descriptor (.msn).
struct MissionDescriptor: Equatable, Sendable {
    let name: String
    /// The levels in LEVEL order (LEVEL 1 first).
    let levels: [MissionLevelDescriptor]
}

enum MissionDescriptorError: Error, Equatable {
    case nonUTF8
    case unsupportedDirective(String)
    case invalidMission
}

func parseMissionDescriptor(_ data: Data) throws -> MissionDescriptor {
    guard let source = String(data: data, encoding: .utf8) else {
        throw MissionDescriptorError.nonUTF8
    }

    var missionName: String?
    var declaredLevelCount: Int?
    var isMultiplayer: Bool?
    var sawDescription = false
    var levels: [(name: String?, mine: String?)] = []

    for rawLine in source.split(whereSeparator: \Character.isNewline) {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.isEmpty || line.hasPrefix(";") || line.hasPrefix("#") {
            continue
        }
        let pieces = line.split(maxSplits: 1, whereSeparator: \Character.isWhitespace)
        let keyword = pieces[0].uppercased()
        let value = pieces.count == 2 ? String(pieces[1]).trimmingCharacters(in: .whitespaces) : ""

        switch keyword {
        case "NAME":
            if levels.isEmpty {
                guard missionName == nil else { throw MissionDescriptorError.invalidMission }
                missionName = value
            } else {
                guard levels[levels.count - 1].name == nil else {
                    throw MissionDescriptorError.invalidMission
                }
                levels[levels.count - 1].name = value
            }
        case "NUMLEVELS":
            guard declaredLevelCount == nil else { throw MissionDescriptorError.invalidMission }
            declaredLevelCount = Int(value)
        case "MULTI":
            guard isMultiplayer == nil else { throw MissionDescriptorError.invalidMission }
            isMultiplayer = value.caseInsensitiveCompare("YES") == .orderedSame
        case "SINGLE":
            guard value.caseInsensitiveCompare("NO") != .orderedSame else {
                throw MissionDescriptorError.unsupportedDirective("SINGLE NO")
            }
        case "AUTHOR", "PROGRESS":
            break
        case "DESCRIPTION":
            guard !sawDescription, !value.isEmpty else {
                throw MissionDescriptorError.invalidMission
            }
            sawDescription = true
        case "LEVEL":
            // LoadMissionLevel numbers the levels from 1, in order.
            guard let index = Int(value), index == levels.count + 1 else {
                throw MissionDescriptorError.invalidMission
            }
            levels.append((nil, nil))
        case "MINE":
            guard !levels.isEmpty, levels[levels.count - 1].mine == nil else {
                throw MissionDescriptorError.invalidMission
            }
            levels[levels.count - 1].mine = value
        default:
            throw MissionDescriptorError.unsupportedDirective(keyword)
        }
    }

    guard sawDescription,
          let missionName,
          !missionName.isEmpty,
          declaredLevelCount == levels.count,
          isMultiplayer == false,
          !levels.isEmpty
    else {
        throw MissionDescriptorError.invalidMission
    }
    let resolved = try levels.map { level -> MissionLevelDescriptor in
        guard let name = level.name, !name.isEmpty,
              let mine = level.mine, !mine.isEmpty else {
            throw MissionDescriptorError.invalidMission
        }
        return MissionLevelDescriptor(name: name, mineSourceName: mine)
    }
    return MissionDescriptor(name: missionName, levels: resolved)
}
