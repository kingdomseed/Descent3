// SPDX-License-Identifier: GPL-3.0-or-later
//
// Imports the data of the compiled game modules (the default scripts) that
// the level's objects bind (M1 step 8b). Source provenance:
// - Descent3/OsirisLoadandBind.cpp:1146 Osiris_LoadGameModule: a module's
//   string table is `<module>.str`, loaded with CreateStringTable when it
//   exists (:1253-1268; StringTableImport.swift). cfile opens it from the
//   first library in search order (cfile/cfile.cpp:264).
// - Descent3/osiris_predefs.cpp:2956 osipf_SoundFindId, :933
//   osipf_WeaponFindID, and :919 osipf_ObjectFindID: the module looks up
//   its sound, weapon, and object pages by name at run time
//   (`DefaultScript.references`). A page the module needs that the tables
//   do not have is an import error.
// - manage/weaponpage.cpp:782: a weapon page and its spawns, which the
//   weapon makes when it times out (WeaponFire.cpp:3162), with its fire
//   image, particle, and explosion frames.

import Foundation

enum GameModuleImportError: Error, Equatable {
    case missingStringTable(String)
    case shortStringTable(module: String, count: Int)
    case unresolvedSound(String)
    case unresolvedWeapon(String)
    case unresolvedObject(String)
}

extension Level {
    /// The level with the data of each compiled game module its objects
    /// reach (`reachedGameModules`): the module's strings and sound
    /// references in `gameModules`, the sound pages it plays added to the sound
    /// clips, the weapons it fires (with their timeout spawns) added to
    /// `weapons`, and the object pages it creates added to `objectInfos`.
    /// Everything keeps a fixed order, so two imports give the same package.
    func addingGameModules(
        archives: [LevelScriptArchive],
        genericPages: [String: RetailGenericPage],
        soundPage: (String) throws -> RetailSoundPageSelection,
        soundClip: (String) throws -> CanonicalSoundClip,
        weapon: (String) throws -> RetailWeaponPresentationSelection,
        weaponModel: (String) -> SourceResource?,
        textureFrames: (String) -> [SourceResource] = { _ in [] },
        fireImage: (String) -> CanonicalWeaponImage? = { _ in nil }
    ) throws -> Level {
        let modules = reachedGameModules
        guard !modules.isEmpty else { return self }

        var level = self
        var addedClips: [CanonicalSoundClip] = []
        func soundKey(_ name: String) throws -> String {
            let clip = try soundClip(name)
            if !(level.soundClips + addedClips).contains(where: {
                $0.logicalName == clip.logicalName
            }) {
                addedClips.append(clip)
            }
            return clip.logicalName
        }
        var gameModules: [GameModuleScripting] = []
        for module in modules {
            let references = DefaultScript.references(module: module)!
            let tableName = module + ".str"
            guard let (archive, entry) = archives.lazy.compactMap({ archive in
                archive.archive.entry(named: tableName).map { (archive, $0) }
            }).first else {
                throw GameModuleImportError.missingStringTable(tableName)
            }
            let strings = try parseStringTable(
                archive.data.subdata(in: entry.payloadRange),
                fileName: tableName
            )
            guard strings.count >= references.stringCount else {
                throw GameModuleImportError.shortStringTable(
                    module: module,
                    count: strings.count
                )
            }
            let sounds = try references.soundNames.map { name in
                let page: RetailSoundPageSelection
                do {
                    page = try soundPage(name)
                } catch {
                    throw GameModuleImportError.unresolvedSound(name)
                }
                return GameModuleSoundReference(
                    name: name,
                    key: try soundKey(name),
                    flags: page.flags
                )
            }
            gameModules.append(.init(
                module: module,
                strings: strings,
                sounds: sounds
            ))

            var weapons = level.weapons ?? []
            var pendingWeapons = references.weaponNames
            while !pendingWeapons.isEmpty {
                let name = pendingWeapons.removeFirst()
                guard !weapons.contains(where: {
                    $0.name.caseInsensitiveCompare(name) == .orderedSame
                }) else {
                    continue
                }
                let page: RetailWeaponPresentationSelection
                do {
                    page = try weapon(name)
                } catch {
                    throw GameModuleImportError.unresolvedWeapon(name)
                }
                let canonical = try Level.canonicalWeapon(
                    page,
                    weaponModel: weaponModel,
                    textureFrames: textureFrames,
                    fireImage: fireImage,
                    soundKey: soundKey
                )
                weapons.append(canonical)
                if let spawn = canonical.spawn {
                    pendingWeapons.append(spawn.weapon)
                    if !spawn.alternateWeapon.isEmpty {
                        pendingWeapons.append(spawn.alternateWeapon)
                    }
                }
            }
            level.weapons = weapons

            var infos = level.objectInfos ?? []
            for name in references.objectPageNames
            where !infos.contains(where: {
                $0.name.caseInsensitiveCompare(name) == .orderedSame
            }) {
                let page = try gameModuleObjectPage(
                    name,
                    genericPages: genericPages
                )
                infos.append(try Level.canonicalObjectInfo(
                    page,
                    weaponBatteries: [],
                    soundKey: soundKey
                ))
            }
            level.objectInfos = infos
        }
        level.gameModules = gameModules
        return level.appendingSoundClips(addedClips)
            .appendingTextureDependencies(
                (level.weapons ?? []).flatMap(\.presentationTextures),
                provenance:
                    "manage/weaponpage.cpp:653-901; Descent3/WeaponFire.cpp:1706-1716, :3162-3201"
            )
    }
}

/// Obj_FindID for a page a game module creates: the generic page with that
/// name, or an import error.
func gameModuleObjectPage(
    _ name: String,
    genericPages: [String: RetailGenericPage]
) throws -> RetailGenericPage {
    guard let page = genericPages[name.lowercased()] else {
        throw GameModuleImportError.unresolvedObject(name)
    }
    return page
}
