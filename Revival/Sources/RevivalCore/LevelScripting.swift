// SPDX-License-Identifier: GPL-3.0-or-later
//
// Generic level script data in the canonical package (package schema 12).
// Source provenance:
// - Descent3/Mission.cpp:1686 InitLevelScript and
//   Descent3/OsirisLoadandBind.cpp:884 get_full_path_to_module: the level
//   module is the level file name, lowercased, without its extension.
// - Descent3/OsirisLoadandBind.cpp:1427 Osiris_BindScriptsToObject: the
//   default module and page name bound to each object.
// - Descent3/osiris_predefs.cpp:3378 osipf_FindObjectName: custom scripts
//   find their objects by name (case-insensitive).
// - The message-file reader that the DALLAS editor generates in every level
//   script (scripts/TrainingMission.cpp:743 ReadMessageFile, :811 GetMessage).
// - Descent3/osiris_predefs.cpp:3356 osipf_FindSoundName (sound page names)
//   and the stream file names passed to aSoundPlaySteamingText.

import Foundation

/// The script data one level needs. Level scripts are compiled Swift; the
/// package only names them and holds the data they look up by name.
struct LevelScripting: Codable, Equatable, Sendable {
    /// The level module name, for example `trainingmission`.
    let levelScript: String
    /// One binding per placed object that can hold a script, in level order.
    let objects: [ObjectScriptBinding]
    /// The level's `.msg` string table, in source order, first name wins.
    let messages: [LevelScriptMessage]
    /// Stream file names the level script plays, mapped to voice clip keys
    /// (`CanonicalVoiceClip.sourceName`).
    let streamedAudio: [LevelScriptAudioReference]
    /// Sound page names the level script plays, mapped to sound clip keys
    /// (`CanonicalSoundClip.logicalName`).
    let sounds: [LevelScriptAudioReference]

    /// GetMessage (TrainingMission.cpp:811) compares names exactly (strcmp).
    func message(named name: String) -> String? {
        messages.first { $0.name == name }?.text
    }
}

/// The script identity of one placed object (OsirisLoadandBind.cpp:1427).
struct ObjectScriptBinding: Codable, Equatable, Sendable {
    let objectHandle: UInt32
    /// The object name that custom scripts look up (LoadLevel.cpp:1612).
    let name: String?
    /// The game module for the default script: the object's custom default
    /// module (LoadLevel.cpp:1729), or else the page module name, as a
    /// lowercased stem (OsirisLoadandBind.cpp:893), for example `aigame`. `nil` when
    /// the module name is empty (no default script) or the type takes only a
    /// custom script (`OBJ_CAMERA`, OsirisLoadandBind.cpp:556).
    let defaultModuleName: String?
    /// The page name used by `GetGOScriptID` in the game and level modules:
    /// the custom default script name (LoadLevel.cpp:1720), or else the
    /// page's script name override, or else the page name. `nil` for a
    /// custom-only type.
    let defaultScriptName: String?
}

struct LevelScriptMessage: Codable, Equatable, Sendable {
    let name: String
    let text: String
}

struct LevelScriptAudioReference: Codable, Equatable, Sendable {
    /// The name as the legacy script writes it.
    let name: String
    /// The canonical clip key in this level.
    let key: String
}

/// The names one compiled level script references at run time. Each level
/// script file lists them next to its translated name tables.
struct LevelScriptReferences: Equatable, Sendable {
    let soundNames: [String]
    let streamedAudioNames: [String]
}

extension LevelScripting {
    /// Legacy limit: MAX_SCRIPT_MESSAGES (TrainingMission.cpp:650).
    static let maximumMessages = 256
    /// OBJ_ROBOT, OBJ_POWERUP, OBJ_CLUTTER, OBJ_BUILDING, OBJ_DOOR, and
    /// OBJ_CAMERA (OsirisLoadandBind.cpp:563 CANTYPEBEASSIGNEDSCRIPT).
    static let scriptableObjectTypes: Set<UInt8> = [2, 7, 9, 11, 16, 17]
    /// OBJ_CAMERA (OsirisLoadandBind.cpp:556 HAVECUSTOMONLY).
    static let customOnlyObjectType: UInt8 = 9
}

extension Level {
    /// Structural checks for package schema 12. Import already resolved every
    /// name; this rejects a damaged or hand-edited package.
    func validateScripting() throws {
        guard let scripting else { return }
        func require(_ condition: Bool, _ what: String) throws {
            guard condition else {
                throw LevelValidationError.invalidScripting(what)
            }
        }
        try require(
            isCanonicalModuleName(scripting.levelScript),
            "level script name"
        )

        let objectsByHandle = Dictionary(
            objects.map { ($0.handle, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var boundHandles = Set<UInt32>()
        for binding in scripting.objects {
            guard let object = objectsByHandle[binding.objectHandle],
                  boundHandles.insert(binding.objectHandle).inserted,
                  LevelScripting.scriptableObjectTypes.contains(object.type),
                  binding.name == object.instanceName
            else {
                throw LevelValidationError.invalidScripting(
                    "object binding \(binding.objectHandle)"
                )
            }
            let customOnly = object.type == LevelScripting.customOnlyObjectType
            try require(
                customOnly
                    ? binding.defaultModuleName == nil
                        && binding.defaultScriptName == nil
                    : binding.defaultScriptName.map { !$0.isEmpty } == true
                        && binding.defaultModuleName.map(isCanonicalModuleName)
                            != false,
                "object binding \(binding.objectHandle)"
            )
        }
        try require(
            boundHandles == Set(objects.filter {
                LevelScripting.scriptableObjectTypes.contains($0.type)
            }.map(\.handle)),
            "object bindings"
        )

        // AddMessageToList stores an empty name too, and GetMessage("")
        // returns it (TrainingMission.cpp:689, :811).
        try require(
            scripting.messages.count <= LevelScripting.maximumMessages
                && Set(scripting.messages.map(\.name)).count
                    == scripting.messages.count,
            "messages"
        )

        // The names must be exactly the ones the compiled level script lists.
        guard let references = LevelModule.scriptReferences(
            forLevelScript: scripting.levelScript
        ) else {
            throw LevelValidationError.invalidScripting("level script name")
        }
        // A stream key is the requested file name, case-folded as cfile
        // looks it up in a library (cfile.cpp:264, HOG names are ASCII).
        let voiceKeys = Set(voiceClips.map(\.sourceName))
        try require(
            scripting.streamedAudio.map(\.name) == references.streamedAudioNames
                && scripting.streamedAudio.allSatisfy {
                    $0.key == $0.name.lowercased() && voiceKeys.contains($0.key)
                },
            "streamed audio"
        )
        // A sound key is the requested page name, compared as FindSoundName
        // does (stricmp, soundload.cpp:566).
        let soundKeys = Set(soundClips.map(\.logicalName))
        try require(
            scripting.sounds.map(\.name) == references.soundNames
                && scripting.sounds.allSatisfy {
                    $0.key.caseInsensitiveCompare($0.name) == .orderedSame
                        && soundKeys.contains($0.key)
                },
            "sounds"
        )
    }
}

/// A module name as get_full_path_to_module leaves it: a lowercased file
/// stem (OsirisLoadandBind.cpp:893).
private func isCanonicalModuleName(_ name: String) -> Bool {
    !name.isEmpty
        && name.allSatisfy {
            $0.isASCII && ($0.isLowercase || $0.isNumber || $0 == "_")
        }
}

extension Level {
    /// osipf_FindObjectName (osiris_predefs.cpp:3378): the handle of the
    /// lowest-slot object with this name (stricmp), or OBJECT_HANDLE_NONE.
    /// Only placed objects have names, and the level scripts look them up
    /// once at InitializeDLL, so the placed objects answer it.
    func findObjectName(_ name: String) -> ObjectHandle {
        objects
            .filter {
                $0.instanceName?.caseInsensitiveCompare(name) == .orderedSame
            }
            .min { $0.slot < $1.slot }
            .map { ObjectHandle($0.handle) } ?? .none
    }

    /// This level with the script data of `source`, if it has any. The
    /// assembly steps rebuild a level from its fields, which would drop it.
    func preservingScripting(of source: Level) -> Level {
        source.scripting.map(addingScripting) ?? self
    }
}
