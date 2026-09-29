// SPDX-License-Identifier: GPL-3.0-or-later
//
// Imports the generic level script data (package schema 12).
// Source provenance:
// - Descent3/Mission.cpp:1686 InitLevelScript: the level module is the level
//   file name with the module extension.
// - Descent3/OsirisLoadandBind.cpp:884 get_full_path_to_module: the module
//   name is lowercased and loses its extension (basename).
// - Descent3/OsirisLoadandBind.cpp:1427 Osiris_BindScriptsToObject: default
//   module and page name for each scriptable object type.
// - Descent3/LoadLevel.cpp:1718 ReadObject: custom default script and module
//   overrides (already decoded into PlacedObject by D3LV127Decoder.swift).
// - manage/generic.cpp:1083 mng_ReadNewGenericPage: module_name (version 18)
//   and script_name_override (version 19).
// - manage/doorpage.cpp:261 mng_ReadNewDoorPage: module_name (version 2).
// - scripts/TrainingMission.cpp:925 InitializeDLL: the message file is the
//   module name plus ".msg"; :743 ReadMessageFile and :811 GetMessage. The
//   DALLAS editor generates the same reader in every level script.
// - Descent3/osiris_predefs.cpp:3356 osipf_FindSoundName (sound pages), and
//   cfile/cfile.cpp:264 (the most recently opened library is searched first)
//   for the stream files passed to aSoundPlaySteamingText.

import Foundation

/// One prepared archive, in cfile search order (the mission archive first).
struct LevelScriptArchive {
    let relativePath: String
    let data: Data
    let archive: HOG2Archive
}

enum LevelScriptImportError: Error, Equatable {
    case invalidLevelFileName(String)
    case missingLevelScript(String)
    case missingMessageFile(String)
    case malformedMessageFile(String)
    case missingObjectPage(handle: UInt32, pageName: String)
    case invalidModuleName(handle: UInt32, moduleName: String)
    case unresolvedStreamedAudio(String)
    case unresolvedSound(String)
}

/// Builds the level's script data. Every name must resolve; the canonical
/// audio keys must name clips that the level already holds. `references`
/// defaults to the names the compiled level script lists (LevelModule).
func importLevelScripting(
    level: Level,
    levelFileName: String,
    archives: [LevelScriptArchive],
    table: Data,
    overlay: Data,
    references: LevelScriptReferences? = nil
) throws -> LevelScripting {
    let levelScript = try levelScriptName(levelFileName: levelFileName)
    guard let references = references
        ?? LevelModule.scriptReferences(forLevelScript: levelScript)
    else {
        throw LevelScriptImportError.missingLevelScript(levelScript)
    }

    let messageFileName = levelScript + ".msg"
    guard let (messageArchive, messageEntry) = firstEntry(
        named: messageFileName,
        in: archives
    ) else {
        throw LevelScriptImportError.missingMessageFile(messageFileName)
    }
    let messages = try parseLevelScriptMessages(
        messageArchive.data.subdata(in: messageEntry.payloadRange),
        fileName: messageFileName
    )

    let pages = try RetailScriptPages(table: table, overlay: overlay)
    let objects = try level.objects
        .filter { LevelScripting.scriptableObjectTypes.contains($0.type) }
        .map { try pages.binding(for: $0) }

    let streamedAudio = try references.streamedAudioNames.map { name in
        guard let (archive, entry) = firstEntry(named: name, in: archives) else {
            throw LevelScriptImportError.unresolvedStreamedAudio(name)
        }
        let key = entry.sourceName.lowercased()
        guard level.voiceClips.contains(where: {
            $0.sourceName == key && $0.sourceArchive == archive.relativePath
        }) else {
            throw LevelScriptImportError.unresolvedStreamedAudio(name)
        }
        return LevelScriptAudioReference(name: name, key: key)
    }

    let sounds = try references.soundNames.map { name in
        let page: RetailSoundPageSelection
        do {
            page = try resolveRetailSoundPage(
                table: table,
                overlay: overlay,
                named: name
            )
        } catch RetailTextureTableError.missingName {
            throw LevelScriptImportError.unresolvedSound(name)
        }
        // The WAV is opened through cfopen, so the first library that holds
        // it wins (cfile.cpp:264), as for streams above.
        guard let (archive, entry) = firstEntry(
            named: page.sourceName,
            in: archives
        ),
            let clip = level.soundClips.first(where: {
                $0.logicalName.caseInsensitiveCompare(page.logicalName)
                    == .orderedSame
                    && $0.sourceName.caseInsensitiveCompare(entry.sourceName)
                        == .orderedSame
                    && $0.sourceArchive == archive.relativePath
            })
        else {
            throw LevelScriptImportError.unresolvedSound(name)
        }
        return LevelScriptAudioReference(name: name, key: clip.logicalName)
    }

    return LevelScripting(
        levelScript: levelScript,
        objects: objects,
        messages: messages,
        streamedAudio: streamedAudio,
        sounds: sounds
    )
}

/// Mission.cpp:1688 replaces the level file extension with the module
/// extension; OsirisLoadandBind.cpp:893 lowercases it and takes the stem.
func levelScriptName(levelFileName: String) throws -> String {
    guard let name = canonicalModuleName(levelFileName) else {
        throw LevelScriptImportError.invalidLevelFileName(levelFileName)
    }
    return name
}

/// get_full_path_to_module (OsirisLoadandBind.cpp:884): a module is known by
/// its lowercased file stem, so `AIGame`, `AIGame.dll`, and `aigame` name the
/// same module (Osiris_FindLoadedModule, :773).
private func canonicalModuleName(_ fileName: String) -> String? {
    let file = fileName.split(separator: "/").last.map(String.init) ?? ""
    let stem = file.lastIndex(of: ".").map { String(file[..<$0]) } ?? file
    let name = stem.lowercased()
    guard !name.isEmpty,
          name.allSatisfy({
              $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_")
          })
    else {
        return nil
    }
    return name
}

/// ReadMessageFile (TrainingMission.cpp:743). cfgetc (cfile.cpp:627) turns
/// CR, CRLF, and LF into one newline, and cf_ReadString (cfile.cpp:783)
/// keeps at most 1,023 bytes of a line and drops the rest. The C string ends
/// at a NUL byte. Each line is then trimmed of whitespace at both ends. Empty
/// lines and `//` comments are skipped, and so is a line without `=`. The
/// name is the text before the first `=` and the message is the rest, both
/// kept as written; an empty name is stored too. At most 256 lines are added
/// (MAX_SCRIPT_MESSAGES). GetMessage returns the first match, so a later
/// duplicate is unreachable and is not stored.
func parseLevelScriptMessages(
    _ data: Data,
    fileName: String
) throws -> [LevelScriptMessage] {
    var messages: [LevelScriptMessage] = []
    var names = Set<String>()
    var addedCount = 0
    for fullLine in legacyTextLines(data) {
        let stored = fullLine.prefix(1_023)
        let rawLine = stored.prefix { $0 != 0 }
        let isSpace: (UInt8) -> Bool = {
            $0 == 0x20 || (0x09...0x0d).contains($0)
        }
        guard let first = rawLine.firstIndex(where: { !isSpace($0) }),
              let last = rawLine.lastIndex(where: { !isSpace($0) })
        else {
            continue
        }
        let line = rawLine[first...last]
        guard !line.starts(with: [0x2f, 0x2f]),
              let separator = line.firstIndex(of: 0x3d)
        else {
            continue
        }
        guard let name = String(data: Data(line[..<separator]), encoding: .utf8),
              let text = String(
                  data: Data(line[line.index(after: separator)...]),
                  encoding: .utf8
              )
        else {
            throw LevelScriptImportError.malformedMessageFile(fileName)
        }
        guard addedCount < LevelScripting.maximumMessages else { break }
        addedCount += 1
        if names.insert(name).inserted {
            messages.append(.init(name: name, text: text))
        }
    }
    return messages
}

/// Text-mode lines as cfgetc returns them: CR, CRLF, and LF each end a line.
private func legacyTextLines(_ data: Data) -> [Data] {
    var lines: [Data] = []
    var current = Data()
    var index = data.startIndex
    while index < data.endIndex {
        let byte = data[index]
        index = data.index(after: index)
        if byte == 0x0a || byte == 0x0d {
            if byte == 0x0d, index < data.endIndex, data[index] == 0x0a {
                index = data.index(after: index)
            }
            lines.append(current)
            current = Data()
        } else {
            current.append(byte)
        }
    }
    lines.append(current)
    return lines
}

private func firstEntry(
    named name: String,
    in archives: [LevelScriptArchive]
) -> (LevelScriptArchive, HOG2Entry)? {
    for archive in archives {
        if let entry = archive.archive.entry(named: name) {
            return (archive, entry)
        }
    }
    return nil
}

/// The script fields of the generic and door pages. Add-on pages (extra.gam)
/// replace table pages of the same name.
private struct RetailScriptPages {
    struct Page {
        let name: String
        let moduleName: String
        let scriptNameOverride: String
    }

    private(set) var generic: [String: Page] = [:]
    private(set) var doors: [String: Page] = [:]

    init(table: Data, overlay: Data) throws {
        for data in [table, overlay] {
            try forEachRetailPage(data) { type, body in
                switch type {
                case 10:
                    let page = try Self.genericPage(body)
                    generic[page.name.lowercased()] = page
                case 5:
                    let page = try Self.doorPage(body)
                    doors[page.name.lowercased()] = page
                default:
                    break
                }
            }
        }
    }

    /// OsirisLoadandBind.cpp:1459-1488.
    func binding(for object: PlacedObject) throws -> ObjectScriptBinding {
        if object.type == LevelScripting.customOnlyObjectType {
            return .init(
                objectHandle: object.handle,
                name: object.instanceName,
                defaultModuleName: nil,
                defaultScriptName: nil
            )
        }
        let pageName = object.definition?.sourceName ?? ""
        let isDoor = object.type == 17
        guard let page = (isDoor ? doors : generic)[pageName.lowercased()] else {
            throw LevelScriptImportError.missingObjectPage(
                handle: object.handle,
                pageName: pageName
            )
        }
        let module: String
        let script: String
        if isDoor {
            module = page.moduleName
            script = page.name
        } else {
            module = object.inertModuleName ?? page.moduleName
            script = object.inertScriptName
                ?? (page.scriptNameOverride.isEmpty
                    ? page.name
                    : page.scriptNameOverride)
        }
        // Osiris_LoadGameModule (OsirisLoadandBind.cpp:1146) binds no default
        // script when the module name is empty.
        let moduleName: String?
        if module.isEmpty {
            moduleName = nil
        } else if let name = canonicalModuleName(module) {
            moduleName = name
        } else {
            throw LevelScriptImportError.invalidModuleName(
                handle: object.handle,
                moduleName: module
            )
        }
        return .init(
            objectHandle: object.handle,
            name: object.instanceName,
            defaultModuleName: moduleName,
            defaultScriptName: script
        )
    }

    /// manage/generic.cpp:1083, read up to script_name_override.
    private static func genericPage(_ body: Data) throws -> Page {
        var cursor = RetailPageCursor(body)
        let version = Int(try cursor.readUInt16())
        let objectType = try cursor.readUInt8()
        let name = try cursor.readCString()
        for _ in 0..<3 { _ = try cursor.readCString(allowEmpty: true) }
        try cursor.skip(12)
        try cursor.skip(version >= 24 ? 2 : 1)
        if objectType == 7, version >= 25 { try cursor.skip(2) }
        _ = try cursor.readCString(allowEmpty: true)
        let module = version >= 18 ? try cursor.readCString(allowEmpty: true) : ""
        let override = version >= 19 ? try cursor.readCString(allowEmpty: true) : ""
        return .init(name: name, moduleName: module, scriptNameOverride: override)
    }

    /// manage/doorpage.cpp:261.
    private static func doorPage(_ body: Data) throws -> Page {
        var cursor = RetailPageCursor(body)
        let version = Int(try cursor.readUInt16())
        let name = try cursor.readCString()
        _ = try cursor.readCString(allowEmpty: true)
        try cursor.skip(13)
        if version >= 3 { try cursor.skip(2) }
        _ = try cursor.readCString(allowEmpty: true)
        _ = try cursor.readCString(allowEmpty: true)
        let module = version >= 2 ? try cursor.readCString(allowEmpty: true) : ""
        return .init(name: name, moduleName: module, scriptNameOverride: "")
    }
}

/// The table page stream: a type byte, then a length that counts itself.
private func forEachRetailPage(
    _ data: Data,
    _ body: (UInt8, Data) throws -> Void
) throws {
    let data = Data(data)
    var offset = 0
    while offset < data.count {
        guard data.count - offset >= 5 else {
            throw RetailTextureTableError.truncated
        }
        var header = RetailPageCursor(data.subdata(in: offset..<(offset + 5)))
        let type = try header.readUInt8()
        let length = Int(try header.readUInt32())
        guard length >= 4, length - 4 <= data.count - offset - 5 else {
            throw RetailTextureTableError.invalidPageLength
        }
        try body(type, data.subdata(in: (offset + 5)..<(offset + 1 + length)))
        offset += 1 + length
    }
}
