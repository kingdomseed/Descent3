// SPDX-License-Identifier: GPL-3.0-or-later
//
// Source provenance: Descent3/Mission.cpp mission declaration parsing and
// LoadMissionLevel's one-based level selection.

import Foundation

struct TrainingMission: Equatable, Sendable {
    let name: String
    let levelName: String
    let mineSourceName: String
}

enum TrainingMissionError: Error, Equatable {
    case nonUTF8
    case unsupportedDirective(String)
    case invalidMission
}

func parseTrainingMission(_ data: Data) throws -> TrainingMission {
    guard let source = String(data: data, encoding: .utf8) else {
        throw TrainingMissionError.nonUTF8
    }

    var missionName: String?
    var declaredLevelCount: Int?
    var isMultiplayer: Bool?
    var currentLevel: Int?
    var levelName: String?
    var mineSourceName: String?
    var sawDescription = false

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
            if currentLevel == nil {
                guard missionName == nil else { throw TrainingMissionError.invalidMission }
                missionName = value
            } else {
                guard levelName == nil else { throw TrainingMissionError.invalidMission }
                levelName = value
            }
        case "NUMLEVELS":
            guard declaredLevelCount == nil else { throw TrainingMissionError.invalidMission }
            declaredLevelCount = Int(value)
        case "MULTI":
            guard isMultiplayer == nil else { throw TrainingMissionError.invalidMission }
            isMultiplayer = value.caseInsensitiveCompare("YES") == .orderedSame
        case "SINGLE":
            guard value.caseInsensitiveCompare("NO") != .orderedSame else {
                throw TrainingMissionError.unsupportedDirective("SINGLE NO")
            }
        case "AUTHOR", "PROGRESS":
            break
        case "DESCRIPTION":
            guard !sawDescription, !value.isEmpty else {
                throw TrainingMissionError.invalidMission
            }
            sawDescription = true
        case "LEVEL":
            guard currentLevel == nil, let index = Int(value), index == 1 else {
                throw TrainingMissionError.invalidMission
            }
            currentLevel = index
        case "MINE":
            guard currentLevel == 1, mineSourceName == nil else {
                throw TrainingMissionError.invalidMission
            }
            mineSourceName = value
        default:
            throw TrainingMissionError.unsupportedDirective(keyword)
        }
    }

    guard sawDescription,
          let missionName,
          missionName == "Pilot Training",
          declaredLevelCount == 1,
          isMultiplayer == false,
          currentLevel == 1,
          let levelName,
          !levelName.isEmpty,
          let mineSourceName,
          !mineSourceName.isEmpty else {
        throw TrainingMissionError.invalidMission
    }

    return TrainingMission(
        name: missionName,
        levelName: levelName,
        mineSourceName: mineSourceName
    )
}
