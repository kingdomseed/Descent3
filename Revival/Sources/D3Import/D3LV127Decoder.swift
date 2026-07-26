// SPDX-License-Identifier: GPL-3.0-or-later
//
// Source provenance: Descent3/LoadLevel.cpp D3LV-127 readers, with checked
// boundary validation replacing legacy assertions, truncation, and fallback IDs.

import CryptoKit
import Foundation

enum D3LV127DecodeError: Error, Equatable {
    case unexpectedChunkOrder([String])
    case malformed(section: String, offset: Int)
    case invalidCount(section: String)
    case unresolvedResource(table: String, index: Int)
    case unsupportedUsedFeature(String)
    case invalidReference(String)
}

private enum D3LV127SourceLimit {
    static let textures = 3_100
    static let objectDefinitions = 910
    static let doors = 60
    static let lightmapPages = 65_534
    // ReadNewLightmapChunk requires the info count to be strictly below MAX_LIGHTMAP_INFOS.
    static let lightmapInfos = 65_533
    static let rooms = 400
    static let roomVertices = 10_000
    static let roomFaces = 3_000
    static let faceCorners = 64
    static let objects = 1_500
    static let paths = 300
    static let pathNodes = 100
    static let goals = 32
    static let goalItems = 12
    static let triggers = 100
    static let playerStarts = 32
    static let terrainSatellites = 5
}

func parseD3LV127(_ data: Data, source: LevelSource) throws -> Level {
    let chunks = try walkD3LV127Chunks(data)
    let expected = [
        "PATH", "TSND", "NLMP", "PSTR", "TXNM", "GNNM", "DRNM", "ROOM", "TERR", "OHND",
        "OBJS", "TRIG", "CNBS", "CBOA", "NODE", "AABB", "MTCN", "LVLG", "LIFE", "INFO", "EDIT",
    ]
    guard chunks.map(\.name) == expected else {
        throw D3LV127DecodeError.unexpectedChunkOrder(chunks.map(\.name))
    }

    let payloads = Dictionary(uniqueKeysWithValues: chunks.map { ($0.name, data.subdata(in: $0.payloadRange)) })
    let textureNames = try parseNameTable(
        payloads["TXNM"]!,
        section: "TXNM",
        maximum: D3LV127SourceLimit.textures
    )
    let genericNames = try parseNameTable(
        payloads["GNNM"]!,
        section: "GNNM",
        maximum: D3LV127SourceLimit.objectDefinitions
    )
    let doorNames = try parseNameTable(
        payloads["DRNM"]!,
        section: "DRNM",
        maximum: D3LV127SourceLimit.doors
    )
    let lightmaps = try parseLightmaps(payloads["NLMP"]!)
    let rooms = try parseRooms(
        payloads["ROOM"]!,
        textureNames: textureNames,
        doorNames: doorNames,
        lightmapCount: lightmaps.infos.count
    )
    let indoorNavigation = try parseIndoorNavigation(
        payloads["NODE"]!,
        rooms: rooms
    )
    let terrain = try parseTerrain(payloads["TERR"]!, textureNames: textureNames)
    let objects = try parseObjects(
        payloads["OBJS"]!,
        genericNames: genericNames,
        doorNames: doorNames,
        lightmapCount: lightmaps.infos.count
    )
    let paths = try parsePaths(payloads["PATH"]!)
    let (goals, goalFlags) = try parseGoals(payloads["LVLG"]!, objects: objects)
    let triggers = try parseTriggers(payloads["TRIG"]!)
    let playerStarts = try parsePlayerStarts(payloads["PSTR"]!)
    let metadata = try parseLevelInfo(payloads["INFO"]!)
    let retiredObjectHandles = try parseRetiredObjectHandles(payloads["OHND"]!)

    try requireZeroCount(payloads["TSND"]!, section: "TSND")
    try requireZeroCount(payloads["MTCN"]!, section: "MTCN")

    let sourceChunks = chunks.map { chunk in
        let payload = data.subdata(in: chunk.payloadRange)
        return SourceChunkRecord(
            name: chunk.name,
            byteCount: payload.count,
            sha256: SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined(),
            disposition: chunkDisposition(
                chunk.name,
                includesCanonicalPresentationPixels: !lightmaps.pages.isEmpty
            )
        )
    }
    let manifest = makeDependencyManifest(
        rooms: rooms,
        terrain: terrain,
        objects: objects,
        lightmaps: lightmaps,
        exactTraining: source.levelSHA256 == "915a561cd3bd720d88bffed72fe41b4ff711c287711f060ecd9696e2cd5f7d41"
    )
    let level = Level(
        missionKey: "descent3.mission.pilot-training",
        levelKey: "descent3.level.training-mission",
        source: source,
        metadata: metadata,
        rooms: rooms,
        terrain: terrain,
        objects: objects,
        retiredObjectHandles: retiredObjectHandles,
        paths: paths,
        goals: goals,
        goalFlags: goalFlags,
        triggers: triggers,
        playerStartFlags: playerStarts,
        indoorNavigation: indoorNavigation,
        lightmaps: lightmaps,
        surfacePhysics: [],
        dependencyManifest: manifest,
        sourceChunks: sourceChunks
    )
    try level.validateForImportStaging()
    return level
}

private func parseIndoorNavigation(
    _ data: Data,
    rooms: [LevelRoom]
) throws -> IndoorNavigationGraph? {
    guard !data.isEmpty else { return nil }
    var cursor = LegacyCursor(data: data, section: "NODE")
    let sourceHighestRoomPlusTerrainRegions = Int(try cursor.readInt16())
    guard let highestRoomSourceIndex = rooms.map(\.sourceIndex).max(),
          sourceHighestRoomPlusTerrainRegions
            == highestRoomSourceIndex + 8
    else {
        throw D3LV127DecodeError.invalidReference("NODE room range")
    }
    var navigationRooms: [IndoorNavigationRoom] = []
    for sourceIndex in 0...sourceHighestRoomPlusTerrainRegions {
        guard try cursor.readUInt8() != 0 else { continue }
        let nodeCount = Int(try cursor.readInt16())
        try cursor.requireCount(
            nodeCount,
            maximum: 127,
            minimumBytes: 14
        )
        var nodes: [IndoorNavigationNode] = []
        nodes.reserveCapacity(nodeCount)
        for _ in 0..<nodeCount {
            let position = try cursor.readVector()
            let edgeCount = Int(try cursor.readInt16())
            try cursor.requireCount(
                edgeCount,
                maximum: 127,
                minimumBytes: 11
            )
            var edges: [IndoorNavigationEdge] = []
            edges.reserveCapacity(edgeCount)
            for _ in 0..<edgeCount {
                edges.append(.init(
                    destinationRoomSourceIndex:
                        Int(try cursor.readInt16()),
                    destinationNodeIndex: Int(try cursor.readUInt8()),
                    flags: Int(try cursor.readInt16()),
                    cost: max(1, Int(try cursor.readInt16())),
                    maximumRadius: try cursor.readFloat()
                ))
            }
            nodes.append(.init(position: position, edges: edges))
        }
        navigationRooms.append(.init(
            sourceIndex: sourceIndex,
            nodes: nodes
        ))
    }
    let sourceWasVerified = try cursor.readUInt8() != 0
    try cursor.requireEnd(allowZeroPadding: true)
    return IndoorNavigationGraph(
        sourceHighestRoomPlusTerrainRegions:
            sourceHighestRoomPlusTerrainRegions,
        sourceWasVerified: sourceWasVerified,
        rooms: navigationRooms
    )
}

private struct LegacyCursor {
    let data: Data
    let section: String
    var offset = 0

    var remaining: Int { data.count - offset }

    mutating func readData(_ count: Int) throws -> Data {
        guard count <= remaining else {
            throw D3LV127DecodeError.malformed(section: section, offset: offset)
        }
        defer { offset += count }
        return data.subdata(in: offset..<(offset + count))
    }

    mutating func readUInt8() throws -> UInt8 { try readData(1)[0] }

    mutating func readUInt16() throws -> UInt16 {
        let bytes = try readData(2)
        return UInt16(bytes[0]) | UInt16(bytes[1]) << 8
    }

    mutating func readInt16() throws -> Int16 { Int16(bitPattern: try readUInt16()) }

    mutating func readUInt32() throws -> UInt32 {
        let bytes = try readData(4)
        return UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
    }

    mutating func readInt32() throws -> Int32 { Int32(bitPattern: try readUInt32()) }

    mutating func readFloat() throws -> Float {
        let value = Float(bitPattern: try readUInt32())
        guard value.isFinite else {
            throw D3LV127DecodeError.malformed(section: section, offset: offset - 4)
        }
        return value
    }

    mutating func readVector() throws -> Vector3 {
        Vector3(x: try readFloat(), y: try readFloat(), z: try readFloat())
    }

    mutating func readCString() throws -> String {
        guard let end = data[offset...].firstIndex(of: 0) else {
            throw D3LV127DecodeError.malformed(section: section, offset: offset)
        }
        let bytes = data[offset..<end]
        guard let value = String(bytes: bytes, encoding: .utf8) else {
            throw D3LV127DecodeError.malformed(section: section, offset: offset)
        }
        offset = end + 1
        return value
    }

    mutating func readLengthPrefixedString() throws -> String? {
        let count = Int(try readUInt8())
        guard count > 0 else { return nil }
        let bytes = try readData(count)
        guard let value = String(data: bytes, encoding: .utf8) else {
            throw D3LV127DecodeError.malformed(section: section, offset: offset - count)
        }
        return value
    }

    mutating func requireCount(
        _ count: Int,
        maximum: Int? = nil,
        minimumBytes: Int
    ) throws {
        guard count >= 0,
              maximum.map({ count <= $0 }) ?? true,
              count <= remaining / minimumBytes else {
            throw D3LV127DecodeError.invalidCount(section: section)
        }
    }

    mutating func requireEnd(allowZeroPadding: Bool = false) throws {
        if offset == data.count { return }
        if allowZeroPadding,
           remaining <= 3,
           data[offset...].allSatisfy({ $0 == 0 }) {
            offset = data.count
            return
        }
        throw D3LV127DecodeError.malformed(section: section, offset: offset)
    }
}

private func parseNameTable(_ data: Data, section: String, maximum: Int) throws -> [String] {
    var cursor = LegacyCursor(data: data, section: section)
    let count = Int(try cursor.readUInt32())
    try cursor.requireCount(count, maximum: maximum, minimumBytes: 1)
    var names: [String] = []
    names.reserveCapacity(count)
    for _ in 0..<count { names.append(try cursor.readCString()) }
    try cursor.requireEnd(allowZeroPadding: true)
    return names
}

private func parseLightmaps(_ data: Data) throws -> LightmapCatalog {
    var cursor = LegacyCursor(data: data, section: "NLMP")
    let pageCount = Int(try cursor.readUInt32())
    try cursor.requireCount(
        pageCount,
        maximum: D3LV127SourceLimit.lightmapPages,
        minimumBytes: 5
    )
    var pages: [LightmapPageMetadata] = []
    pages.reserveCapacity(pageCount)
    for _ in 0..<pageCount {
        let width = Int(try cursor.readUInt16())
        let height = Int(try cursor.readUInt16())
        guard (1...128).contains(width),
              (1...128).contains(height) else {
            throw D3LV127DecodeError.invalidCount(section: "NLMP pages")
        }
        let pixelCount = width * height
        let pixels = try readCompressedUInt16(&cursor, count: pixelCount)
        pages.append(
            .init(
                width: width,
                height: height,
                rgba8: canonicalRGBA8From1555(pixels)
            )
        )
    }

    let infoCount = Int(try cursor.readUInt32())
    try cursor.requireCount(
        infoCount,
        maximum: D3LV127SourceLimit.lightmapInfos,
        minimumBytes: 35
    )
    var infos: [LightmapInfoRecord] = []
    infos.reserveCapacity(infoCount)
    for _ in 0..<infoCount {
        let pageIndex = Int(try cursor.readUInt16())
        let width = Int(try cursor.readUInt16())
        let height = Int(try cursor.readUInt16())
        let type = try cursor.readUInt8()
        let x = Int(try cursor.readInt16())
        let y = Int(try cursor.readInt16())
        let xSpacing = try cursor.readUInt8()
        let ySpacing = try cursor.readUInt8()
        let upperLeft = try cursor.readVector()
        let normal = try cursor.readVector()
        guard pages.indices.contains(pageIndex), width >= 2, height >= 2 else {
            throw D3LV127DecodeError.invalidReference("NLMP page")
        }
        infos.append(
            .init(
                pageIndex: pageIndex,
                width: width,
                height: height,
                type: type,
                x: x,
                y: y,
                xSpacing: xSpacing,
                ySpacing: ySpacing,
                upperLeft: upperLeft,
                normal: normal
            )
        )
    }
    try cursor.requireEnd(allowZeroPadding: true)
    return LightmapCatalog(pages: pages, infos: infos)
}

private func parseRooms(
    _ data: Data,
    textureNames: [String],
    doorNames: [String],
    lightmapCount: Int
) throws -> [LevelRoom] {
    var cursor = LegacyCursor(data: data, section: "ROOM")
    let roomCount = Int(try cursor.readUInt32())
    let declaredVertices = Int(try cursor.readUInt32())
    let declaredFaces = Int(try cursor.readUInt32())
    let declaredFaceVertices = Int(try cursor.readUInt32())
    let declaredPortals = Int(try cursor.readUInt32())
    try cursor.requireCount(roomCount, maximum: D3LV127SourceLimit.rooms, minimumBytes: 43)

    var rooms: [LevelRoom] = []
    rooms.reserveCapacity(roomCount)
    var totals = (vertices: 0, faces: 0, faceVertices: 0, portals: 0)
    var indices = Set<Int>()

    for _ in 0..<roomCount {
        let sourceIndex = Int(try cursor.readInt16())
        guard (0..<D3LV127SourceLimit.rooms).contains(sourceIndex),
              indices.insert(sourceIndex).inserted else {
            throw D3LV127DecodeError.invalidReference("ROOM source index")
        }
        let vertexCount = Int(try cursor.readUInt32())
        let faceCount = Int(try cursor.readUInt32())
        let portalCount = Int(try cursor.readUInt32())
        try cursor.requireCount(
            vertexCount,
            maximum: D3LV127SourceLimit.roomVertices,
            minimumBytes: 12
        )
        let sourceName = try cursor.readCString()
        let pathPoint = try cursor.readVector()
        var vertices: [Vector3] = []
        vertices.reserveCapacity(vertexCount)
        for _ in 0..<vertexCount { vertices.append(try cursor.readVector()) }

        try cursor.requireCount(
            faceCount,
            maximum: D3LV127SourceLimit.roomFaces,
            minimumBytes: 41
        )
        var faces: [LevelFace] = []
        faces.reserveCapacity(faceCount)
        for _ in 0..<faceCount {
            let cornerCount = Int(try cursor.readUInt8())
            guard (3...D3LV127SourceLimit.faceCorners).contains(cornerCount) else {
                throw D3LV127DecodeError.invalidCount(section: "ROOM face")
            }
            try cursor.requireCount(
                cornerCount,
                maximum: D3LV127SourceLimit.faceCorners,
                minimumBytes: 11
            )
            var vertexIndices: [Int] = []
            vertexIndices.reserveCapacity(cornerCount)
            for _ in 0..<cornerCount { vertexIndices.append(Int(try cursor.readUInt16())) }
            var uv: [(Float, Float, UInt8)] = []
            uv.reserveCapacity(cornerCount)
            for _ in 0..<cornerCount {
                uv.append((try cursor.readFloat(), try cursor.readFloat(), try cursor.readUInt8()))
            }
            let flags = try cursor.readUInt16()
            let rawPortal = try cursor.readUInt8()
            let textureIndex = Int(try cursor.readUInt16())
            let texture = try resource(textureNames, index: textureIndex, table: "TXNM")
            var lightmapIndex: Int?
            var lightmapUV: [(Float, Float)] = []
            if flags & 1 != 0 {
                let index = Int(try cursor.readUInt16())
                guard (0..<lightmapCount).contains(index) else {
                    throw D3LV127DecodeError.invalidReference("ROOM lightmap")
                }
                lightmapIndex = index
                for _ in 0..<cornerCount { lightmapUV.append((try cursor.readFloat(), try cursor.readFloat())) }
            }
            let lightMultiple = try cursor.readUInt8()
            let hasSpecial = try cursor.readUInt8()
            var special: SpecialFace?
            if hasSpecial != 0 {
                let type = try cursor.readUInt8()
                let pointCount = Int(try cursor.readUInt8())
                let smoothed = try cursor.readUInt8() != 0
                let normalCount = smoothed ? Int(try cursor.readUInt8()) : 0
                try cursor.requireCount(pointCount, minimumBytes: 14)
                var points: [SpecialFacePoint] = []
                points.reserveCapacity(pointCount)
                for _ in 0..<pointCount {
                    points.append(.init(center: try cursor.readVector(), color: try cursor.readUInt16()))
                }
                try cursor.requireCount(normalCount, minimumBytes: 12)
                var normals: [Vector3] = []
                normals.reserveCapacity(normalCount)
                for _ in 0..<normalCount { normals.append(try cursor.readVector()) }
                special = .init(type: type, points: points, smoothedVertexNormals: normals)
            }
            let corners = vertexIndices.indices.map { index in
                FaceCorner(
                    vertexIndex: vertexIndices[index],
                    u: uv[index].0,
                    v: uv[index].1,
                    alpha: uv[index].2,
                    lightmapU: lightmapIndex == nil ? nil : lightmapUV[index].0,
                    lightmapV: lightmapIndex == nil ? nil : lightmapUV[index].1
                )
            }
            faces.append(
                .init(
                    corners: corners,
                    flags: flags,
                    portalIndex: rawPortal == 0xff ? nil : Int(rawPortal),
                    texture: texture,
                    lightmapInfoIndex: lightmapIndex,
                    allowsLightCorona: flags & 0x0005 == 0x0005,
                    lightMultiple: lightMultiple,
                    special: special
                )
            )
            totals.faceVertices += cornerCount
        }

        try cursor.requireCount(portalCount, minimumBytes: 32)
        var portals: [LevelPortal] = []
        portals.reserveCapacity(portalCount)
        for _ in 0..<portalCount {
            portals.append(
                .init(
                    flags: try cursor.readUInt32(),
                    faceIndex: Int(try cursor.readInt16()),
                    connectedRoom: Int(try cursor.readInt32()),
                    connectedPortal: Int(try cursor.readInt32()),
                    boundaryNodeIndex: Int(try cursor.readInt16()),
                    pathPoint: try cursor.readVector(),
                    combineMaster: Int(try cursor.readInt32())
                )
            )
        }

        let roomFlags = try cursor.readUInt32()
        let pulseTime = try cursor.readUInt8()
        let pulseOffset = try cursor.readUInt8()
        let rawMirror = Int(try cursor.readInt16())
        var door: RoomDoor?
        if roomFlags & 2 != 0 {
            let flags = try cursor.readUInt8()
            let keys = try cursor.readUInt8()
            let storedIndex = Int(try cursor.readInt32())
            let position = try cursor.readFloat()
            door = .init(
                flags: flags,
                keysNeeded: keys,
                definition: try resource(doorNames, index: storedIndex, table: "DRNM"),
                position: position
            )
        }
        var volumeLights: VolumeLightGrid?
        if try cursor.readUInt8() != 0 {
            let width = Int(try cursor.readInt32())
            let height = Int(try cursor.readInt32())
            let depth = Int(try cursor.readInt32())
            guard (0...Int(Int16.max)).contains(width),
                  (0...Int(Int16.max)).contains(height),
                  (0...Int(Int16.max)).contains(depth) else {
                throw D3LV127DecodeError.invalidCount(section: "ROOM volume lights")
            }
            let count = width * height * depth
            volumeLights = .init(
                width: width,
                height: height,
                depth: depth,
                values: try readCompressedBytes(&cursor, count: count)
            )
        }
        let fog = RoomFog(
            depth: try cursor.readFloat(),
            red: try cursor.readFloat(),
            green: try cursor.readFloat(),
            blue: try cursor.readFloat()
        )
        let ambient = try cursor.readCString()
        let reverb = try cursor.readUInt8()
        let damage = try cursor.readFloat()
        let damageType = try cursor.readUInt8()
        rooms.append(
            .init(
                sourceIndex: sourceIndex,
                name: sourceName.isEmpty ? nil : sourceName,
                pathPoint: pathPoint,
                vertices: vertices,
                faces: faces,
                portals: portals,
                flags: roomFlags,
                pulseTime: pulseTime,
                pulseOffset: pulseOffset,
                mirrorFaceIndex: rawMirror == -1 ? nil : rawMirror,
                door: door,
                volumeLights: volumeLights,
                fog: fog,
                ambientSoundPattern: ambient.isEmpty ? nil : ambient,
                reverb: reverb,
                damage: damage,
                damageType: damageType
            )
        )
        totals.vertices += vertexCount
        totals.faces += faceCount
        totals.portals += portalCount
    }
    guard totals.vertices == declaredVertices,
          totals.faces == declaredFaces,
          totals.faceVertices == declaredFaceVertices,
          totals.portals == declaredPortals else {
        throw D3LV127DecodeError.invalidCount(section: "ROOM aggregate")
    }
    try cursor.requireEnd(allowZeroPadding: true)
    return rooms
}

private func parseTerrain(_ data: Data, textureNames: [String]) throws -> LevelTerrain {
    let chunks = try walkNestedChunks(data, section: "TERR")
    guard chunks.map(\.name) == ["TERH", "TETM", "TSKY", "TEND"] else {
        throw D3LV127DecodeError.unexpectedChunkOrder(chunks.map(\.name))
    }
    let payloads = Dictionary(uniqueKeysWithValues: chunks.map { ($0.name, data.subdata(in: $0.payloadRange)) })

    var heightCursor = LegacyCursor(data: payloads["TERH"]!, section: "TERH")
    let heights = try readCompressedBytes(&heightCursor, count: 65_536)
    try heightCursor.requireEnd(allowZeroPadding: true)

    var textureCursor = LegacyCursor(data: payloads["TETM"]!, section: "TETM")
    let storedTextures = try readCompressedUInt16(&textureCursor, count: 1_024)
    let rotations = try readCompressedBytes(&textureCursor, count: 1_024)
    let flags = try readCompressedBytes(&textureCursor, count: 65_536)
    try textureCursor.requireEnd(allowZeroPadding: true)
    let textureCells = try storedTextures.indices.map { index in
        TerrainTextureCell(
            texture: try resource(textureNames, index: Int(storedTextures[index]), table: "TXNM"),
            rotationAndTile: rotations[index]
        )
    }

    var skyCursor = LegacyCursor(data: payloads["TSKY"]!, section: "TSKY")
    let fogScalar = try skyCursor.readFloat()
    let damagePerSecond = try skyCursor.readFloat()
    let textured = try skyCursor.readUInt8() != 0
    let dome = try resource(textureNames, index: Int(try skyCursor.readUInt16()), table: "TXNM")
    let skyColor = try skyCursor.readUInt32()
    let horizonColor = try skyCursor.readUInt32()
    let fogColor = try skyCursor.readUInt32()
    let skyFlags = try skyCursor.readUInt32()
    let radius = try skyCursor.readFloat()
    let rotationRate = try skyCursor.readFloat()
    let satelliteCount = Int(try skyCursor.readInt32())
    try skyCursor.requireCount(
        satelliteCount,
        maximum: D3LV127SourceLimit.terrainSatellites,
        minimumBytes: 31
    )
    var satellites: [TerrainSatellite] = []
    satellites.reserveCapacity(satelliteCount)
    for _ in 0..<satelliteCount {
        satellites.append(
            .init(
                texture: try resource(textureNames, index: Int(try skyCursor.readUInt16()), table: "TXNM"),
                vector: try skyCursor.readVector(),
                flags: try skyCursor.readUInt8(),
                size: try skyCursor.readFloat(),
                red: try skyCursor.readFloat(),
                green: try skyCursor.readFloat(),
                blue: try skyCursor.readFloat()
            )
        )
    }
    let light = try readCompressedBytes(&skyCursor, count: 65_536)
    let red = try readCompressedBytes(&skyCursor, count: 65_536)
    let green = try readCompressedBytes(&skyCursor, count: 65_536)
    let blue = try readCompressedBytes(&skyCursor, count: 65_536)
    let dynamic = try readCompressedBytes(&skyCursor, count: 65_536)
    let occlusionChecksum = try skyCursor.readUInt32()
    let occlusion = try readCompressedBytes(&skyCursor, count: 8_192)
    try skyCursor.requireEnd(allowZeroPadding: true)
    guard payloads["TEND"]!.isEmpty else {
        throw D3LV127DecodeError.malformed(section: "TEND", offset: 0)
    }
    return LevelTerrain(
        heights: heights,
        textureCells: textureCells,
        flags: flags,
        light: light,
        red: red,
        green: green,
        blue: blue,
        dynamicLight: dynamic,
        occlusionChecksum: occlusionChecksum,
        occlusionMap: occlusion,
        sky: .init(
            fogScalar: fogScalar,
            damagePerSecond: damagePerSecond,
            textured: textured,
            domeTexture: dome,
            skyColor: skyColor,
            horizonColor: horizonColor,
            fogColor: fogColor,
            flags: skyFlags,
            radius: radius,
            rotationRate: rotationRate,
            satellites: satellites
        )
    )
}

private func parseObjects(
    _ data: Data,
    genericNames: [String],
    doorNames: [String],
    lightmapCount: Int
) throws -> [PlacedObject] {
    var cursor = LegacyCursor(data: data, section: "OBJS")
    let count = Int(try cursor.readUInt32())
    try cursor.requireCount(count, maximum: D3LV127SourceLimit.objects, minimumBytes: 70)
    var objects: [PlacedObject] = []
    objects.reserveCapacity(count)
    for _ in 0..<count {
        let handle = try cursor.readUInt32()
        let type = try cursor.readUInt8()
        let storedIndex = Int(try cursor.readInt16())
        guard D3SourceIdentity.isValidHandle(handle),
              D3SourceIdentity.isSerializedObjectType(type),
              D3SourceIdentity.isValidSerializedObjectIdentity(
                  storedID: storedIndex,
                  type: type
              ) else {
            throw D3LV127DecodeError.invalidReference("OBJS identity")
        }
        let instanceName = try cursor.readCString()
        let flags = try cursor.readUInt32()
        let doorShields = type == 17 ? try cursor.readInt16() : nil
        let rawRoom = try cursor.readInt32()
        let position = try cursor.readVector()
        let sourceMatrix = Matrix3(
            right: try cursor.readVector(),
            up: try cursor.readVector(),
            forward: try cursor.readVector()
        )
        let orientation = try orthogonalized(sourceMatrix)
        let containsType = try cursor.readUInt8()
        let containsID = try cursor.readUInt8()
        let containsCount = try cursor.readUInt8()
        let lifeLeft = try cursor.readFloat()
        let sound: ObjectSoundSource?
        if type == 24 {
            let name = try cursor.readCString()
            sound = .init(sourceName: name.isEmpty ? nil : name, volume: try cursor.readFloat())
        } else {
            sound = nil
        }
        let script = try cursor.readLengthPrefixedString()
        let module = try cursor.readLengthPrefixedString()
        var submodels: [ObjectLightmapSubmodel] = []
        if try cursor.readUInt8() != 0 {
            let submodelCount = Int(try cursor.readUInt8())
            try cursor.requireCount(submodelCount, minimumBytes: 2)
            submodels.reserveCapacity(submodelCount)
            for _ in 0..<submodelCount {
                let faceCount = Int(try cursor.readUInt16())
                try cursor.requireCount(faceCount, minimumBytes: 27)
                var faces: [ObjectLightmapFace] = []
                faces.reserveCapacity(faceCount)
                for _ in 0..<faceCount {
                    let infoIndex = Int(try cursor.readUInt16())
                    guard (0..<lightmapCount).contains(infoIndex) else {
                        throw D3LV127DecodeError.invalidReference("OBJS lightmap")
                    }
                    let right = try cursor.readVector()
                    let up = try cursor.readVector()
                    let vertexCount = Int(try cursor.readUInt8())
                    try cursor.requireCount(vertexCount, minimumBytes: 8)
                    var uv: [LightmapUV] = []
                    uv.reserveCapacity(vertexCount)
                    for _ in 0..<vertexCount {
                        uv.append(.init(u: try cursor.readFloat(), v: try cursor.readFloat()))
                    }
                    faces.append(.init(lightmapInfoIndex: infoIndex, right: right, up: up, uv: uv))
                }
                submodels.append(.init(faces: faces))
            }
        }
        let definition: SourceResource?
        if [2, 7, 11, 16].contains(type) {
            let runtime = storedIndex == 67 && genericNames.indices.contains(67)
                && genericNames[67].caseInsensitiveCompare("Invisiblepowerup") == .orderedSame ? 68 : nil
            definition = try resource(genericNames, index: storedIndex, table: "GNNM", runtimeIndex: runtime)
        } else if type == 17 {
            definition = try resource(doorNames, index: storedIndex, table: "DRNM")
        } else {
            definition = nil
        }
        objects.append(
            .init(
                handle: handle,
                type: type,
                storedID: storedIndex,
                definition: definition,
                instanceName: instanceName.isEmpty ? nil : instanceName,
                flags: flags,
                doorShields: doorShields,
                location: spatialLocation(rawRoom),
                position: position,
                orientation: orientation,
                containsType: containsType,
                containsID: containsID,
                containsCount: containsCount,
                lifeLeft: lifeLeft,
                soundSource: sound,
                inertScriptName: script,
                inertModuleName: module,
                lightmapSubmodels: submodels
            )
        )
    }
    try cursor.requireEnd(allowZeroPadding: true)
    return objects
}

private func parsePaths(_ data: Data) throws -> [GamePath] {
    var cursor = LegacyCursor(data: data, section: "PATH")
    let count = Int(try cursor.readUInt16())
    try cursor.requireCount(count, maximum: D3LV127SourceLimit.paths, minimumBytes: 7)
    var paths: [GamePath] = []
    paths.reserveCapacity(count)
    for _ in 0..<count {
        let name = try cursor.readCString()
        let nodeCount = Int(try cursor.readInt32())
        let flags = try cursor.readUInt8()
        try cursor.requireCount(
            nodeCount,
            maximum: D3LV127SourceLimit.pathNodes,
            minimumBytes: 44
        )
        var nodes: [GamePathNode] = []
        nodes.reserveCapacity(nodeCount)
        for _ in 0..<nodeCount {
            nodes.append(
                .init(
                    position: try cursor.readVector(),
                    location: spatialLocation(try cursor.readInt32()),
                    flags: try cursor.readUInt32(),
                    forward: try cursor.readVector(),
                    up: try cursor.readVector()
                )
            )
        }
        paths.append(.init(name: name, flags: flags, nodes: nodes))
    }
    try cursor.requireEnd(allowZeroPadding: true)
    return paths
}

private func parseGoals(_ data: Data, objects: [PlacedObject]) throws -> ([LevelGoal], UInt32) {
    var cursor = LegacyCursor(data: data, section: "LVLG")
    guard try cursor.readUInt16() == 4 else {
        throw D3LV127DecodeError.unsupportedUsedFeature("LVLG version")
    }
    let count = Int(try cursor.readUInt16())
    try cursor.requireCount(count, maximum: D3LV127SourceLimit.goals, minimumBytes: 21)
    let handles = Set(objects.map(\.handle))
    var goals: [LevelGoal] = []
    goals.reserveCapacity(count)
    for _ in 0..<count {
        let status = try cursor.readUInt32()
        let priority = try cursor.readInt32()
        let list = Int8(bitPattern: try cursor.readUInt8())
        let name = try readUInt16String(&cursor)
        let itemName = try readUInt16String(&cursor)
        let description = try readUInt16String(&cursor)
        let completion = try readUInt16String(&cursor)
        let itemCount = Int(try cursor.readUInt16())
        try cursor.requireCount(
            itemCount,
            maximum: D3LV127SourceLimit.goalItems,
            minimumBytes: 6
        )
        var items: [LevelGoalItem] = []
        items.reserveCapacity(itemCount)
        for _ in 0..<itemCount {
            let type = try cursor.readUInt8()
            let sourceHandle = try cursor.readUInt32()
            guard handles.contains(sourceHandle) else {
                throw D3LV127DecodeError.invalidReference("LVLG object handle")
            }
            items.append(
                .init(
                    type: type,
                    sourceHandle: sourceHandle,
                    objectHandle: sourceHandle,
                    done: try cursor.readUInt8() != 0
                )
            )
        }
        goals.append(
            .init(
                status: status,
                priority: priority,
                list: list,
                name: name,
                itemName: itemName,
                description: description,
                completionMessage: completion,
                items: items
            )
        )
    }
    let flags = try cursor.readUInt32()
    try cursor.requireEnd(allowZeroPadding: true)
    return (goals, flags)
}

private func parseTriggers(_ data: Data) throws -> [LevelTrigger] {
    var cursor = LegacyCursor(data: data, section: "TRIG")
    let count = Int(try cursor.readUInt32())
    try cursor.requireCount(count, maximum: D3LV127SourceLimit.triggers, minimumBytes: 9)
    var triggers: [LevelTrigger] = []
    for _ in 0..<count {
        triggers.append(
            .init(
                name: try cursor.readCString(),
                roomIndex: Int(try cursor.readInt16()),
                faceIndex: Int(try cursor.readInt16()),
                flags: try cursor.readUInt16(),
                activator: try cursor.readUInt16()
            )
        )
    }
    try cursor.requireEnd(allowZeroPadding: true)
    return triggers
}

private func parsePlayerStarts(_ data: Data) throws -> [UInt32] {
    var cursor = LegacyCursor(data: data, section: "PSTR")
    let count = Int(try cursor.readUInt16())
    try cursor.requireCount(
        count,
        maximum: D3LV127SourceLimit.playerStarts,
        minimumBytes: 4
    )
    var flags: [UInt32] = []
    flags.reserveCapacity(count)
    for _ in 0..<count { flags.append(try cursor.readUInt32()) }
    try cursor.requireEnd(allowZeroPadding: true)
    return flags
}

private func parseLevelInfo(_ data: Data) throws -> LevelMetadata {
    var cursor = LegacyCursor(data: data, section: "INFO")
    let name = try cursor.readCString()
    let designer = try cursor.readCString()
    let copyright = try cursor.readCString()
    let notes = try cursor.readCString()
    let gravity = try cursor.readFloat()
    let alwaysCheckCeiling = try cursor.readInt32() != 0
    let ceiling = try cursor.readFloat()
    try cursor.requireEnd(allowZeroPadding: true)
    return .init(
        name: name,
        designer: designer,
        copyright: copyright,
        notes: notes,
        gravity: gravity,
        alwaysCheckCeiling: alwaysCheckCeiling,
        ceilingHeight: ceiling
    )
}

private func requireZeroCount(_ data: Data, section: String) throws {
    var cursor = LegacyCursor(data: data, section: section)
    guard try cursor.readInt32() == 0 else {
        throw D3LV127DecodeError.unsupportedUsedFeature(section)
    }
    try cursor.requireEnd(allowZeroPadding: true)
}

private func parseRetiredObjectHandles(_ data: Data) throws -> [UInt32] {
    var cursor = LegacyCursor(data: data, section: "OHND")
    let count = Int(try cursor.readUInt32())
    try cursor.requireCount(count, maximum: D3LV127SourceLimit.objects, minimumBytes: 4)
    var handles: [UInt32] = []
    handles.reserveCapacity(count)
    for _ in 0..<count {
        let handle = try cursor.readUInt32()
        guard D3SourceIdentity.isValidHandle(handle) else {
            throw D3LV127DecodeError.invalidReference("OHND identity")
        }
        handles.append(handle)
    }
    try cursor.requireEnd(allowZeroPadding: true)
    return handles
}

private func readCompressedBytes(_ cursor: inout LegacyCursor, count: Int) throws -> [UInt8] {
    let compressed = try cursor.readUInt8()
    if compressed == 0 {
        try cursor.requireCount(count, minimumBytes: 1)
        return [UInt8](try cursor.readData(count))
    }
    try requireFeasibleCompressedOutput(
        count,
        encodedBytesPerCommand: 2,
        remainingBytes: cursor.remaining,
        section: "\(cursor.section) compressed UInt8"
    )
    var result: [UInt8] = []
    result.reserveCapacity(count)
    while result.count < count {
        let command = try cursor.readUInt8()
        guard command == 0 || (2...250).contains(command) else {
            throw D3LV127DecodeError.malformed(section: cursor.section, offset: cursor.offset - 1)
        }
        let value = try cursor.readUInt8()
        let run = command == 0 ? 1 : Int(command)
        guard run <= count - result.count else {
            throw D3LV127DecodeError.invalidCount(section: "\(cursor.section) compressed UInt8")
        }
        result.append(contentsOf: repeatElement(value, count: run))
    }
    return result
}

private func readCompressedUInt16(_ cursor: inout LegacyCursor, count: Int) throws -> [UInt16] {
    let compressed = try cursor.readUInt8()
    if compressed == 0 {
        try cursor.requireCount(count, minimumBytes: 2)
        var result: [UInt16] = []
        result.reserveCapacity(count)
        for _ in 0..<count { result.append(try cursor.readUInt16()) }
        return result
    }
    try requireFeasibleCompressedOutput(
        count,
        encodedBytesPerCommand: 3,
        remainingBytes: cursor.remaining,
        section: "\(cursor.section) compressed UInt16"
    )
    var result: [UInt16] = []
    result.reserveCapacity(count)
    while result.count < count {
        let command = try cursor.readUInt8()
        guard command == 0 || (2...250).contains(command) else {
            throw D3LV127DecodeError.malformed(section: cursor.section, offset: cursor.offset - 1)
        }
        let value = try cursor.readUInt16()
        let run = command == 0 ? 1 : Int(command)
        guard run <= count - result.count else {
            throw D3LV127DecodeError.invalidCount(section: "\(cursor.section) compressed UInt16")
        }
        result.append(contentsOf: repeatElement(value, count: run))
    }
    return result
}

private func requireFeasibleCompressedOutput(
    _ count: Int,
    encodedBytesPerCommand: Int,
    remainingBytes: Int,
    section: String
) throws {
    let maximumOutput = remainingBytes / encodedBytesPerCommand * 250
    guard count <= maximumOutput else {
        throw D3LV127DecodeError.invalidCount(section: section)
    }
}

private func readUInt16String(_ cursor: inout LegacyCursor) throws -> String {
    let count = Int(try cursor.readUInt16())
    let data = try cursor.readData(count)
    guard let value = String(data: data, encoding: .utf8) else {
        throw D3LV127DecodeError.malformed(section: cursor.section, offset: cursor.offset - count)
    }
    return value
}

private func resource(
    _ names: [String],
    index: Int,
    table: String,
    runtimeIndex: Int? = nil
) throws -> SourceResource {
    guard names.indices.contains(index), !names[index].isEmpty else {
        throw D3LV127DecodeError.unresolvedResource(table: table, index: index)
    }
    return .init(storedIndex: index, sourceName: names[index], referenceRuntimeIndex: runtimeIndex)
}

private func spatialLocation(_ raw: Int32) -> SpatialLocation {
    let value = UInt32(bitPattern: raw)
    return value & 0x8000_0000 == 0
        ? .room(Int(raw))
        : .terrainCell(Int(value & 0x7fff_ffff))
}

private func orthogonalized(_ matrix: Matrix3) throws -> Matrix3 {
    let forward = try normalized(matrix.forward)
    let right = try normalized(cross(matrix.up, forward))
    return Matrix3(right: right, up: cross(forward, right), forward: forward)
}

private func normalized(_ vector: Vector3) throws -> Vector3 {
    let magnitude = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
    guard magnitude.isFinite, magnitude > 0 else {
        throw D3LV127DecodeError.invalidReference("object orientation")
    }
    return .init(x: vector.x / magnitude, y: vector.y / magnitude, z: vector.z / magnitude)
}

private func cross(_ a: Vector3, _ b: Vector3) -> Vector3 {
    .init(
        x: a.y * b.z - a.z * b.y,
        y: a.z * b.x - a.x * b.z,
        z: a.x * b.y - a.y * b.x
    )
}

private func walkNestedChunks(_ data: Data, section: String) throws -> [D3LV127Chunk] {
    var cursor = LegacyCursor(data: data, section: section)
    var chunks: [D3LV127Chunk] = []
    while cursor.remaining > 0 {
        let headerOffset = cursor.offset
        let nameData = try cursor.readData(4)
        guard nameData.allSatisfy({ $0 >= 0x20 && $0 <= 0x7e }) else {
            throw D3LV127DecodeError.malformed(section: section, offset: headerOffset)
        }
        let name = String(decoding: nameData, as: UTF8.self)
        let declaredSize = Int(try cursor.readInt32())
        guard declaredSize >= 4 else {
            throw D3LV127DecodeError.malformed(section: section, offset: headerOffset)
        }
        let payloadStart = cursor.offset
        let payloadCount = declaredSize - 4
        _ = try cursor.readData(payloadCount)
        chunks.append(.init(name: name, payloadRange: payloadStart..<(payloadStart + payloadCount)))
    }
    return chunks
}

private func makeDependencyManifest(
    rooms: [LevelRoom],
    terrain: LevelTerrain,
    objects: [PlacedObject],
    lightmaps: LightmapCatalog,
    exactTraining: Bool
) -> DependencyManifest {
    var records: [DependencyRecord] = []
    var seen = Set<String>()
    func append(
        _ category: String,
        _ source: SourceResource,
        _ provenance: String,
        state: String = "identity-recorded"
    ) {
        let key = "\(category):\(source.sourceName.lowercased())"
        if seen.insert(key).inserted {
            records.append(.init(category: category, source: source, state: state, provenance: provenance))
        }
    }
    for room in rooms {
        for face in room.faces { append("texture", face.texture, "ROOM face") }
        if let door = room.door { append("door-definition", door.definition, "ROOM door") }
    }
    for cell in terrain.textureCells { append("texture", cell.texture, "TERR texture cell") }
    if let sky = terrain.sky {
        append("texture", sky.domeTexture, "TERR sky dome")
        for satellite in sky.satellites { append("texture", satellite.texture, "TERR satellite") }
    }
    for object in objects {
        if [2, 7, 11, 16].contains(object.type), let definition = object.definition {
            append("object-definition", definition, "OBJS placed object")
        } else if object.type == 17, let definition = object.definition {
            append("door-definition", definition, "OBJS placed object")
        }
    }
    for index in lightmaps.pages.indices {
        append(
            "lightmap-page",
            .init(storedIndex: index, sourceName: "lightmap-page-\(index)"),
            "NLMP page metadata",
            state: "payload-validated-preparation-deferred"
        )
    }
    for index in lightmaps.infos.indices {
        append(
            "lightmap-info",
            .init(storedIndex: index, sourceName: "lightmap-info-\(index)"),
            "NLMP metadata"
        )
    }
    return DependencyManifest(
        current: records,
        historicalEagerBaseline: exactTraining
            ? .init(textureCount: 232, soundCount: 115, modelCount: 88, lightmapInfoCount: 2_531)
            : nil
    )
}

private func chunkDisposition(
    _ name: String,
    includesCanonicalPresentationPixels: Bool
) -> String {
    switch name {
    case "PATH", "PSTR", "TXNM", "GNNM", "DRNM", "ROOM", "TERR", "OBJS", "TRIG", "LVLG", "INFO":
        return "canonical"
    case "NLMP":
        return includesCanonicalPresentationPixels
            ? "canonical-metadata-and-importer-staging-rgba-pixels"
            : "canonical-metadata"
    case "TSND", "MTCN":
        return "validated-empty"
    case "CNBS", "CBOA", "AABB":
        return "derived-cache-excluded"
    case "NODE":
        return "canonical-indoor-boundary-navigation"
    case "OHND":
        return "canonical-retired-handle-continuity"
    case "LIFE":
        return "evidence-only-future-opportunity-f-001"
    case "EDIT":
        return "evidence-only-phase-1-slice-3-native-editor-state"
    default:
        preconditionFailure("unaccounted D3LV chunk \(name)")
    }
}
