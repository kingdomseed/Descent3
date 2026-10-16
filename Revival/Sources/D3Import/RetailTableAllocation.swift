// SPDX-License-Identifier: GPL-3.0-or-later
//
// Table identity allocation from manage/manage.cpp:1212 mng_LoadNetPages,
// manage/texpage.cpp:919-1011, :1118, :1241, manage/weaponpage.cpp:1240-1542,
// manage/generic.cpp:1840-2053, :2329, manage/shippage.cpp:1013-1085,
// and manage/megapage.cpp:175-194, :250-270.

import Foundation

func allocateRetailTexturePages(
    table: Data,
    overlay: Data
) throws -> [String: RetailTexturePage] {
    var allocation = try RetailTableAllocation(table: table, overlay: overlay)
    return try allocation.load()
}

private struct RetailTableAllocation {
    private struct Identity: Hashable {
        let kind: UInt8
        let name: String
    }

    private enum Page {
        case texture(RetailTexturePage)
        case weapon(RetailWeaponPresentationSelection)
        case generic(RetailGenericPage)
        case ship(RetailShipDefinition)
        case megacell(String, [String])
        case ignored

        var identity: Identity? {
            switch self {
            case let .texture(page):
                .init(kind: 1, name: page.name.lowercased())
            case let .weapon(page):
                .init(kind: 2, name: page.name.lowercased())
            case let .generic(page):
                .init(kind: 10, name: page.name.lowercased())
            case let .ship(page):
                .init(kind: 6, name: page.name.lowercased())
            case let .megacell(name, _):
                .init(kind: 8, name: name.lowercased())
            case .ignored:
                nil
            }
        }
    }

    private struct Record {
        let end: Int
        let page: Page
    }

    private struct Table {
        let data: Data
        let records: [Record]

        init(_ data: Data) throws {
            self.data = data
            var records: [Record] = []
            var position = 0
            while position < data.count {
                let record = try Self.readRecord(data, at: position)
                records.append(record)
                position = record.end
            }
            self.records = records
        }

        private static func readRecord(_ data: Data, at position: Int) throws -> Record {
            guard data.count - position >= 5 else {
                throw RetailTextureTableError.truncated
            }
            let length = Int(readTableUInt32(data, at: position + 1))
            guard length >= 4, length - 4 <= data.count - position - 5 else {
                throw RetailTextureTableError.invalidPageLength
            }
            let end = position + 1 + length
            let framed = Data(data[position..<end])
            let page: Page
            switch data[position] {
            case 1:
                guard let texture = try parseRetailTexturePages(framed).first else {
                    throw RetailTextureTableError.invalidName
                }
                page = .texture(texture)
            case 2:
                guard let weapon = try parseRetailWeaponPresentations(framed).first else {
                    throw RetailTextureTableError.invalidName
                }
                page = .weapon(weapon)
            case 6:
                guard let ship = try parseRetailModelPages(framed).first?.shipDefinition else {
                    throw RetailTextureTableError.invalidName
                }
                page = .ship(ship)
            case 8:
                var cursor = RetailPageCursor(Data(data[(position + 5)..<end]))
                _ = try cursor.readUInt16()
                let name = try cursor.readCString()
                let cells = try (0..<64).map { _ in
                    try cursor.readCString(allowEmpty: true)
                }
                _ = try cursor.readUInt8()
                _ = try cursor.readUInt8()
                try cursor.requireEnd()
                page = .megacell(name, cells)
            case 10:
                guard let generic = try parseRetailGenericPages(framed).first else {
                    throw RetailTextureTableError.invalidName
                }
                page = .generic(generic)
            case 0, 5, 7, 9:
                page = .ignored
            default:
                throw RetailTextureTableError.invalidPageLength
            }
            return .init(end: end, page: page)
        }

        func find(kind: UInt8, name: String, offset: Int) throws -> Page? {
            var position = offset
            while position < data.count {
                guard data.count - position >= 5 else { return nil }
                let length = Int(readTableUInt32(data, at: position + 1))
                guard length >= 4, length - 4 <= data.count - position - 5 else {
                    return nil
                }
                if data[position] == kind {
                    let record = try Self.readRecord(data, at: position)
                    if record.page.identity?.name == name { return record.page }
                }
                position += 1 + length
            }
            return nil
        }
    }

    private struct Context {
        let overlay: Bool
        let offset: Int
    }

    private let base: Table
    private let extra: Table
    // InitTextures (Descent3/gametexture.cpp:299-315).
    private var loaded: Set<Identity> = [.init(kind: 1, name: "sample texture")]
    private var textures: [String: RetailTexturePage] = [:]
    private var genericWeaponCapabilities: [String: Bool] = [:]
    private var nextTextureIndex = 1

    init(table: Data, overlay: Data) throws {
        base = try Table(table)
        extra = try Table(overlay)
    }

    mutating func load() throws -> [String: RetailTexturePage] {
        for record in base.records {
            try visit(record, overlay: false)
        }
        for record in extra.records {
            try visit(record, overlay: true)
        }
        return textures
    }

    private mutating func visit(_ record: Record, overlay: Bool) throws {
        guard let identity = record.page.identity else { return }
        let exists = loaded.contains(identity)
        if exists && !overlay { return }
        if overlay && identity.kind == 8 {
            throw RetailTextureTableError.unsupportedPresentation("extra.gam megacell")
        }
        try assign(record.page, context: .init(
            overlay: overlay,
            offset: exists ? 0 : record.end
        ))
    }

    private mutating func ensure(
        kind: UInt8,
        name: String,
        context: Context
    ) throws {
        let identity = Identity(kind: kind, name: name.lowercased())
        if loaded.contains(identity) { return }
        let first = context.overlay ? extra : base
        let found = try first.find(kind: kind, name: identity.name, offset: context.offset)
        let page: Page?
        if found == nil && kind != 2 && !context.overlay {
            page = try extra.find(kind: kind, name: identity.name, offset: context.offset)
        } else {
            page = found
        }
        guard let page else { return }
        try assign(page, context: .init(
            overlay: context.overlay,
            offset: kind == 10 ? 0 : context.offset
        ))
    }

    private mutating func assign(_ page: Page, context: Context) throws {
        guard let identity = page.identity else { return }
        let new = loaded.insert(identity).inserted
        switch page {
        case let .texture(source):
            let index: Int
            if let existing = textures[identity.name] {
                index = existing.storedIndex
            } else if identity.name == "sample texture" {
                index = 0
            } else {
                guard nextTextureIndex < 3_100 else {
                    throw RetailTextureTableError.invalidPageLength
                }
                index = nextTextureIndex
                nextTextureIndex += 1
            }
            var texture = source.replacingStoredIndex(index)
            if texture.flags & 128 != 0 && texture.destroyedTextureName.lowercased() == identity.name {
                texture.flags &= ~128
            }
            textures[identity.name] = texture
            if texture.flags & 128 != 0 {
                try ensure(kind: 1, name: texture.destroyedTextureName, context: context)
            }
        case let .weapon(weapon):
            for name in [weapon.explosionTextureName, weapon.particleName]
            where Self.isNamedWeaponDependency(name) {
                try ensure(kind: 1, name: name, context: context)
            }
            for name in [weapon.timeoutSpawnName, weapon.alternateSpawnName]
            where Self.isNamedWeaponDependency(name) {
                try ensure(kind: 2, name: name, context: context)
            }
            if Self.isNamedWeaponDependency(weapon.robotSpawnName) {
                try ensure(kind: 10, name: weapon.robotSpawnName, context: context)
            }
            for name in [weapon.smokeTextureName, weapon.scorchTextureName, weapon.iconTextureName]
            where Self.isNamedWeaponDependency(name) {
                try ensure(kind: 1, name: name, context: context)
            }
        case let .generic(generic):
            if new {
                genericWeaponCapabilities[identity.name] = generic.flags & 1 != 0
                    || generic.weaponBatteries.contains {
                        $0.fireMasks.prefix($0.numberOfMasks).contains { $0 != 0 }
                    }
            }
            for spew in generic.deathSpew.entries where !spew.pageName.isEmpty {
                try ensure(kind: 10, name: spew.pageName, context: context)
            }
            if genericWeaponCapabilities[identity.name] == true {
                for name in generic.weaponNames.flatMap({ $0 }) where !name.isEmpty {
                    try ensure(kind: 2, name: name, context: .init(overlay: context.overlay, offset: 0))
                }
            }
        case let .ship(ship):
            for battery in ship.weaponBatteries ?? [] {
                for name in battery.weaponNames where !name.isEmpty {
                    try ensure(kind: 2, name: name, context: context)
                }
            }
            for battery in ship.weaponBatteries ?? [] where !battery.spewPowerupName.isEmpty {
                try ensure(kind: 10, name: battery.spewPowerupName, context: context)
            }
        case let .megacell(_, names):
            for name in names where name.lowercased() != "invalid image name" {
                try ensure(kind: 1, name: name, context: .init(overlay: context.overlay, offset: 0))
            }
        case .ignored:
            break
        }
    }

    private static func isNamedWeaponDependency(_ name: String) -> Bool {
        !name.isEmpty && name.lowercased() != "invalid name"
    }
}
