// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

// The bounded ACM decoder below is a direct Swift translation of the ISC-licensed
// `third_party/libacm/decode.c`; the OSF wrapper follows the released
// `lib/audio/streamaudio.cpp` header contract. Maintained commit
// 113b0ba4ecd1fc43d31c31b8ae49013e658a4446 supplies the adopted invariant that
// the ACM header's channel count is authoritative instead of forcing mono to stereo.
struct DecodedOSFVoice: Equatable, Sendable {
    let sampleRate: Int
    let channelCount: Int
    let frameCount: Int
    let pcm16LittleEndian: Data
}

struct ReachedPCM16Audio: Equatable, Sendable {
    let sampleRate: Int
    let channelCount: Int
    let frameCount: Int
    let pcm16LittleEndian: Data
}

enum ReachedWAVDecodeError: Error, Equatable {
    case truncated
    case invalidHeader
    case unsupportedFormat
    case missingData
}

func decodeReachedPCM16WAV(_ data: Data) throws -> ReachedPCM16Audio {
    guard data.count >= 12,
          data[0..<4].elementsEqual("RIFF".utf8),
          data[8..<12].elementsEqual("WAVE".utf8) else {
        throw ReachedWAVDecodeError.invalidHeader
    }
    let declaredBodyCount = Int(readTableUInt32(data, at: 4))
    guard declaredBodyCount == data.count - 8 else {
        throw ReachedWAVDecodeError.truncated
    }
    let riffEnd = data.count
    var offset = 12
    var format: (
        sampleRate: Int,
        channelCount: Int,
        blockAlign: Int
    )?
    var pcm: Data?
    while offset <= riffEnd - 8 {
        let name = String(decoding: data[offset..<(offset + 4)], as: UTF8.self)
        let count = Int(readTableUInt32(data, at: offset + 4))
        let bodyStart = offset + 8
        guard count >= 0, count <= riffEnd - bodyStart else {
            throw ReachedWAVDecodeError.truncated
        }
        if name == "fmt " {
            guard count >= 16 else {
                throw ReachedWAVDecodeError.truncated
            }
            let audioFormat =
                UInt16(data[bodyStart])
                    | UInt16(data[bodyStart + 1]) << 8
            let channels =
                Int(UInt16(data[bodyStart + 2])
                    | UInt16(data[bodyStart + 3]) << 8)
            let rate = Int(readTableUInt32(data, at: bodyStart + 4))
            let blockAlign =
                Int(UInt16(data[bodyStart + 12])
                    | UInt16(data[bodyStart + 13]) << 8)
            let bits =
                Int(UInt16(data[bodyStart + 14])
                    | UInt16(data[bodyStart + 15]) << 8)
            guard audioFormat == 1,
                  (1...2).contains(channels),
                  (4_096...192_000).contains(rate),
                  bits == 16,
                  blockAlign == channels * 2 else {
                throw ReachedWAVDecodeError.unsupportedFormat
            }
            format = (rate, channels, blockAlign)
        } else if name == "data" {
            pcm = Data(data[bodyStart..<(bodyStart + count)])
        }
        let paddedEnd = bodyStart + count + (count & 1)
        guard paddedEnd <= riffEnd else {
            throw ReachedWAVDecodeError.truncated
        }
        offset = paddedEnd
    }
    guard offset == riffEnd else {
        throw ReachedWAVDecodeError.truncated
    }
    guard let format, let pcm else {
        throw ReachedWAVDecodeError.missingData
    }
    guard !pcm.isEmpty, pcm.count % format.blockAlign == 0 else {
        throw ReachedWAVDecodeError.unsupportedFormat
    }
    return .init(
        sampleRate: format.sampleRate,
        channelCount: format.channelCount,
        frameCount: pcm.count / format.blockAlign,
        pcm16LittleEndian: pcm
    )
}

enum OSFACMDecodeError: Error, Equatable {
    case truncated
    case invalidOSF
    case unsupportedOSF
    case invalidACM
    case corruptACM
}

func decodeOSFACMVoice(_ data: Data) throws -> DecodedOSFVoice {
    let headerSize = 128
    guard data.count > headerSize else { throw OSFACMDecodeError.truncated }
    let headerOffset = data.count - headerSize
    guard data[headerOffset..<(headerOffset + 4)].elementsEqual("OSF1".utf8) else {
        throw OSFACMDecodeError.invalidOSF
    }
    let type = data[headerOffset + 4]
    let compression = data[headerOffset + 5]
    let format = data[headerOffset + 6]
    let rateCode = data[headerOffset + 7]
    guard type == 0, compression == 1, format & 0x01 == 0x01 else {
        throw OSFACMDecodeError.unsupportedOSF
    }
    let osfRate: Int?
    switch rateCode {
    case 0: osfRate = nil
    case 11: osfRate = 11_025
    case 22: osfRate = 22_050
    case 44: osfRate = 44_100
    default: throw OSFACMDecodeError.unsupportedOSF
    }

    var decoder = try ACMDecoder(data: data.prefix(headerOffset))
    guard osfRate.map({ decoder.sampleRate == $0 }) ?? true else {
        throw OSFACMDecodeError.invalidOSF
    }
    let pcm = try decoder.decodeAll()
    return DecodedOSFVoice(
        sampleRate: decoder.sampleRate,
        channelCount: decoder.channelCount,
        frameCount: pcm.count / 2 / decoder.channelCount,
        pcm16LittleEndian: pcm
    )
}

private struct ACMBitReader {
    let data: Data
    var bitOffset = 0
    private let sourceEOFZeroPaddingBits = 8

    mutating func read(_ count: Int) throws -> UInt32 {
        guard (0...31).contains(count),
              bitOffset <= data.count * 8 + sourceEOFZeroPaddingBits
                - count else {
            throw OSFACMDecodeError.truncated
        }
        var value: UInt32 = 0
        for bit in 0..<count {
            let sourceBit = bitOffset + bit
            if sourceBit < data.count * 8 {
                let byte = data[sourceBit >> 3]
                value |= UInt32((byte >> (sourceBit & 7)) & 1) << bit
            }
        }
        bitOffset += count
        return value
    }
}

private struct ACMDecoder {
    private var bits: ACMBitReader
    let totalValueCount: Int
    let channelCount: Int
    let sampleRate: Int
    private let level: Int
    private let rows: Int
    private let columns: Int
    private var wrap: [Int64]

    init(data: Data) throws {
        var bits = ACMBitReader(data: data)
        guard try bits.read(24) == 0x03_28_97,
              try bits.read(8) == 1 else {
            throw OSFACMDecodeError.invalidACM
        }
        let low = try bits.read(16)
        let high = try bits.read(16)
        let valueCount = Int(low | high << 16)
        let channels = Int(try bits.read(16))
        let rate = Int(try bits.read(16))
        let level = Int(try bits.read(4))
        let rows = Int(try bits.read(12))
        guard valueCount > 0,
              (1...2).contains(channels),
              rate >= 4_096,
              level <= 15,
              rows > 0,
              rows <= Int.max >> level else {
            throw OSFACMDecodeError.invalidACM
        }
        let columns = 1 << level
        guard rows * columns <= 1_048_576 else {
            throw OSFACMDecodeError.invalidACM
        }
        self.bits = bits
        totalValueCount = valueCount
        channelCount = channels
        sampleRate = rate
        self.level = level
        self.rows = rows
        self.columns = columns
        wrap = Array(repeating: 0, count: max(0, columns * 2 - 2))
    }

    mutating func decodeAll() throws -> Data {
        var remaining = totalValueCount
        var result = Data()
        result.reserveCapacity(totalValueCount * 2)
        while remaining > 0 {
            guard let block = try decodeBlock() else { break }
            let count = min(remaining, block.count)
            guard channelCount == 1 || count % channelCount == 0 else {
                throw OSFACMDecodeError.corruptACM
            }
            for value in block.prefix(count) {
                let shifted = value >> level
                let sample = Int16(truncatingIfNeeded: shifted)
                result.append(UInt8(truncatingIfNeeded: sample))
                result.append(UInt8(truncatingIfNeeded: sample >> 8))
            }
            remaining -= count
        }
        return result
    }

    private mutating func decodeBlock() throws -> [Int64]? {
        guard let powerBits = try readExpectingEnd(4),
              let amplitudeBits = try readExpectingEnd(16) else {
            return nil
        }
        let power = Int(powerBits)
        let amplitude = Int64(amplitudeBits)
        guard power <= 15 else { throw OSFACMDecodeError.corruptACM }
        var block = Array(repeating: Int64(0), count: rows * columns)
        for column in 0..<columns {
            guard let fillerBits = try readExpectingEnd(5) else { return nil }
            let filler = Int(fillerBits)
            try fill(
                filler,
                column: column,
                amplitude: amplitude,
                block: &block
            )
        }
        juggle(&block)
        return block
    }

    private mutating func readExpectingEnd(_ count: Int) throws -> UInt32? {
        do {
            return try bits.read(count)
        } catch OSFACMDecodeError.truncated {
            return nil
        }
    }

    private mutating func fill(
        _ filler: Int,
        column: Int,
        amplitude: Int64,
        block: inout [Int64]
    ) throws {
        func store(_ row: Int, _ symbol: Int) {
            block[row * columns + column] = Int64(symbol) * amplitude
        }
        let one = [-1, 1]
        let twoNear = [-2, -1, 1, 2]
        let twoFar = [-3, -2, 2, 3]
        let three = [-4, -3, -2, -1, 1, 2, 3, 4]
        var row = 0
        switch filler {
        case 0:
            return
        case 3...16:
            let middle = 1 << (filler - 1)
            while row < rows {
                store(row, Int(try bits.read(filler)) - middle)
                row += 1
            }
        case 17:
            while row < rows {
                if try bits.read(1) == 0 {
                    row += min(2, rows - row)
                } else if try bits.read(1) == 0 {
                    row += 1
                } else {
                    store(row, one[Int(try bits.read(1))])
                    row += 1
                }
            }
        case 18:
            while row < rows {
                if try bits.read(1) != 0 {
                    store(row, one[Int(try bits.read(1))])
                }
                row += 1
            }
        case 19:
            while row < rows {
                let packed = Int(try bits.read(5))
                guard packed < 27 else { throw OSFACMDecodeError.corruptACM }
                let values = [
                    packed % 3 - 1,
                    packed / 3 % 3 - 1,
                    packed / 9 - 1,
                ]
                for value in values where row < rows {
                    store(row, value)
                    row += 1
                }
            }
        case 20:
            while row < rows {
                if try bits.read(1) == 0 {
                    row += min(2, rows - row)
                } else if try bits.read(1) == 0 {
                    row += 1
                } else {
                    store(row, twoNear[Int(try bits.read(2))])
                    row += 1
                }
            }
        case 21:
            while row < rows {
                if try bits.read(1) != 0 {
                    store(row, twoNear[Int(try bits.read(2))])
                }
                row += 1
            }
        case 22:
            while row < rows {
                let packed = Int(try bits.read(7))
                guard packed < 125 else { throw OSFACMDecodeError.corruptACM }
                let values = [
                    packed % 5 - 2,
                    packed / 5 % 5 - 2,
                    packed / 25 - 2,
                ]
                for value in values where row < rows {
                    store(row, value)
                    row += 1
                }
            }
        case 23:
            while row < rows {
                if try bits.read(1) == 0 {
                    row += min(2, rows - row)
                } else if try bits.read(1) == 0 {
                    row += 1
                } else if try bits.read(1) == 0 {
                    store(row, one[Int(try bits.read(1))])
                    row += 1
                } else {
                    store(row, twoFar[Int(try bits.read(2))])
                    row += 1
                }
            }
        case 24:
            while row < rows {
                if try bits.read(1) != 0 {
                    if try bits.read(1) == 0 {
                        store(row, one[Int(try bits.read(1))])
                    } else {
                        store(row, twoFar[Int(try bits.read(2))])
                    }
                }
                row += 1
            }
        case 26:
            while row < rows {
                if try bits.read(1) == 0 {
                    row += min(2, rows - row)
                } else if try bits.read(1) == 0 {
                    row += 1
                } else {
                    store(row, three[Int(try bits.read(3))])
                    row += 1
                }
            }
        case 27:
            while row < rows {
                if try bits.read(1) != 0 {
                    store(row, three[Int(try bits.read(3))])
                }
                row += 1
            }
        case 29:
            while row < rows {
                let packed = Int(try bits.read(7))
                guard packed < 121 else { throw OSFACMDecodeError.corruptACM }
                for value in [packed % 11 - 5, packed / 11 - 5] where row < rows {
                    store(row, value)
                    row += 1
                }
            }
        default:
            throw OSFACMDecodeError.corruptACM
        }
    }

    private mutating func juggle(_ block: inout [Int64]) {
        guard level > 0 else { return }
        let stepRows = level > 9 ? 1 : (2_048 >> level) - 2
        var rowsRemaining = rows
        var blockOffset = 0
        repeat {
            var subCount = min(stepRows, rowsRemaining) * 2
            var subLength = columns / 2
            var wrapOffset = 0
            jugglePass(
                block: &block,
                blockOffset: blockOffset,
                wrapOffset: wrapOffset,
                subLength: subLength,
                subCount: subCount
            )
            wrapOffset += subLength * 2
            var position = blockOffset
            for _ in 0..<subCount {
                block[position] += 1
                position += subLength
            }
            while subLength > 1 {
                subLength /= 2
                subCount *= 2
                jugglePass(
                    block: &block,
                    blockOffset: blockOffset,
                    wrapOffset: wrapOffset,
                    subLength: subLength,
                    subCount: subCount
                )
                wrapOffset += subLength * 2
            }
            if rowsRemaining <= stepRows { break }
            rowsRemaining -= stepRows
            blockOffset += stepRows << level
        } while true
    }

    private mutating func jugglePass(
        block: inout [Int64],
        blockOffset: Int,
        wrapOffset: Int,
        subLength: Int,
        subCount: Int
    ) {
        for column in 0..<subLength {
            var position = blockOffset + column
            var r0 = wrap[wrapOffset + column * 2]
            var r1 = wrap[wrapOffset + column * 2 + 1]
            for _ in 0..<(subCount / 2) {
                let r2 = block[position]
                block[position] = r1 * 2 + r0 + r2
                position += subLength
                let r3 = block[position]
                block[position] = r2 * 2 - r1 - r3
                position += subLength
                r0 = r2
                r1 = r3
            }
            wrap[wrapOffset + column * 2] = r0
            wrap[wrapOffset + column * 2 + 1] = r1
        }
    }
}

struct Outrage1555Image: Equatable, Sendable {
    let width: Int
    let height: Int
    let rgba8: Data
    let sourceWasARGB4444: Bool
}

private enum LegacyOGFPixelFormat: Equatable {
    case argb1555
    case argb4444
}

enum Outrage1555DecodeError: Error, Equatable {
    case truncated
    case unsupportedHeader
    case invalidName
    case invalidDimensions
    case invalidRun
    case trailingBytes
}

struct RetailTextureDefinition: Equatable, Sendable {
    let storedIndex: Int
    let name: String
    let bitmapSourceName: String
    let blend: PresentationBlend
    let lightmapBlend: PresentationLightmapBlend
    let waterProcedural: WaterProceduralDefinition?
    let lightCorona: RetailLightCoronaDefinition?
}

struct RetailLightCoronaDefinition: Equatable, Sendable {
    let bitmapSourceName: String
    let tint: Vector3
    let blend: PresentationBlend
}

enum RetailTextureTableError: Error, Equatable {
    case truncated
    case invalidPageLength
    case unsupportedTextureVersion(Int)
    case invalidName
    case missingName(String)
    case unsupportedPresentation(String)
}

func resolveRetailTextureDefinitions(
    table: Data,
    overlay: Data,
    names requestedNames: Set<String>
) throws -> [RetailTextureDefinition] {
    let pages = try mergedRetailTexturePages(table: table, overlay: overlay)
    return try requestedNames.sorted().map { name in
        try canonicalTextureDefinition(resolvedRetailTexturePage(named: name, in: pages))
    }
}

func resolveRetailSurfacePhysics(
    table: Data,
    overlay: Data,
    textures: Set<SourceResource>
) throws -> [SurfacePhysicsEntry] {
    let pages = try mergedRetailTexturePages(table: table, overlay: overlay)
    return try textures.sorted {
        if $0.storedIndex != $1.storedIndex {
            return $0.storedIndex < $1.storedIndex
        }
        return $0.sourceName < $1.sourceName
    }.map { texture in
        let page: RetailTexturePage
        do {
            page = try resolvedRetailTexturePage(named: texture.sourceName, in: pages)
        } catch let error as RetailTextureTableError {
            guard case .missingName = error,
                  let behavior = sourceDefaultSurfaceBehavior(texture) else {
                throw error
            }
            return SurfacePhysicsEntry(
                texture: texture,
                behavior: behavior
            )
        }
        let behavior: SurfacePhysicsBehavior
        if page.flags & 0x0001_0000 != 0 {
            behavior = .passThrough
        } else if page.flags & 0x0000_0020 != 0 {
            behavior = .forceField
        } else {
            behavior = .blocking
        }
        return SurfacePhysicsEntry(texture: texture, behavior: behavior)
    }
}

private func sourceDefaultSurfaceBehavior(
    _ texture: SourceResource
) -> SurfacePhysicsBehavior? {
    switch (texture.storedIndex, texture.sourceName.lowercased()) {
    case (0, "sample texture"), (1, "rainbow texture"):
        .blocking
    default:
        nil
    }
}

private struct MergedRetailTexturePages {
    let byName: [String: RetailTexturePage]
    let byBitmapBase: [String: RetailTexturePage]
}

private func mergedRetailTexturePages(
    table: Data,
    overlay: Data
) throws -> MergedRetailTexturePages {
    let basePages = try parseRetailTexturePages(table)
    let overlayPages = try parseRetailTexturePages(overlay)
    var pageByName: [String: RetailTexturePage] = [:]
    for page in basePages {
        let key = page.name.lowercased()
        guard pageByName[key] == nil else { continue }
        pageByName[key] = page
    }
    var nextStoredIndex = (basePages.map(\.storedIndex).max() ?? -1) + 1
    for page in overlayPages {
        let key = page.name.lowercased()
        if let replaced = pageByName[key] {
            pageByName[key] = page.replacingStoredIndex(replaced.storedIndex)
        } else {
            pageByName[key] = page.replacingStoredIndex(nextStoredIndex)
            nextStoredIndex += 1
        }
    }
    var pageByBitmapBase: [String: RetailTexturePage] = [:]
    for page in pageByName.values where !page.bitmapSourceName.isEmpty {
        let base = URL(fileURLWithPath: page.bitmapSourceName)
            .deletingPathExtension().lastPathComponent.lowercased()
        if pageByBitmapBase[base] == nil { pageByBitmapBase[base] = page }
    }
    return .init(byName: pageByName, byBitmapBase: pageByBitmapBase)
}

private func resolvedRetailTexturePage(
    named name: String,
    in pages: MergedRetailTexturePages
) throws -> RetailTexturePage {
    let key = URL(fileURLWithPath: name)
        .deletingPathExtension().lastPathComponent.lowercased()
    guard let page = pages.byBitmapBase[key] ?? pages.byName[key] else {
        throw RetailTextureTableError.missingName(name)
    }
    return page
}

private struct RetailTexturePage {
    let storedIndex: Int
    let name: String
    let bitmapSourceName: String
    let lightColor: Vector3
    let coronaType: UInt8
    let flags: UInt32
    let alpha: Float
    let procedural: RetailProceduralPage?
}

private extension RetailTexturePage {
    func replacingStoredIndex(_ index: Int) -> RetailTexturePage {
        .init(
            storedIndex: index,
            name: name,
            bitmapSourceName: bitmapSourceName,
            lightColor: lightColor,
            coronaType: coronaType,
            flags: flags,
            alpha: alpha,
            procedural: procedural
        )
    }
}

private struct RetailProceduralPage {
    let lighting: UInt8
    let thickness: UInt8
    let evaluationIntervalSeconds: Float
    let oscillationTimeSeconds: Float
    let elements: [RetailProceduralElement]
}

private struct RetailProceduralElement {
    let type: UInt8
    let frequency: UInt8
    let speed: UInt8
    let size: UInt8
    let x1: UInt8
    let y1: UInt8
    let x2: UInt8
    let y2: UInt8
}

private func parseRetailTexturePages(_ data: Data) throws -> [RetailTexturePage] {
    var offset = 0
    var pages: [RetailTexturePage] = []
    var textureIndex = 0
    while offset < data.count {
        guard data.count - offset >= 5 else { throw RetailTextureTableError.truncated }
        let type = data[offset]
        let length = Int(readTableUInt32(data, at: offset + 1))
        guard length >= 4, length - 4 <= data.count - offset - 5 else {
            throw RetailTextureTableError.invalidPageLength
        }
        let body = data[(offset + 5)..<(offset + 1 + length)]
        if type == 1 {
            var cursor = RetailPageCursor(Data(body))
            let version = Int(try cursor.readUInt16())
            guard version == 7 else {
                throw RetailTextureTableError.unsupportedTextureVersion(version)
            }
            let name = try cursor.readCString(allowEmpty: true)
            let bitmapSourceName = try cursor.readCString(allowEmpty: true)
            _ = try cursor.readCString(allowEmpty: true)
            let red = try cursor.readFloat()
            let green = try cursor.readFloat()
            let blue = try cursor.readFloat()
            let alpha = try cursor.readFloat()
            _ = try cursor.readFloat()
            _ = try cursor.readFloat()
            _ = try cursor.readFloat()
            _ = try cursor.readFloat()
            let coronaType = try cursor.readUInt8()
            _ = try cursor.readUInt32()
            let flags = try cursor.readUInt32()
            let procedural: RetailProceduralPage?
            if flags & 0x0100_0000 != 0 {
                try cursor.skip(255 * 2)
                _ = try cursor.readUInt8()
                let lighting = try cursor.readUInt8()
                let thickness = try cursor.readUInt8()
                let evaluationIntervalSeconds = try cursor.readFloat()
                let oscillationTimeSeconds = try cursor.readFloat()
                _ = try cursor.readUInt8()
                let elementCount = Int(try cursor.readUInt16())
                guard elementCount <= 8_000,
                      elementCount <= cursor.remaining / 8 else {
                    throw RetailTextureTableError.invalidPageLength
                }
                var elements: [RetailProceduralElement] = []
                elements.reserveCapacity(elementCount)
                for _ in 0..<elementCount {
                    elements.append(
                        .init(
                            type: try cursor.readUInt8(),
                            frequency: try cursor.readUInt8(),
                            speed: try cursor.readUInt8(),
                            size: try cursor.readUInt8(),
                            x1: try cursor.readUInt8(),
                            y1: try cursor.readUInt8(),
                            x2: try cursor.readUInt8(),
                            y2: try cursor.readUInt8()
                        )
                    )
                }
                procedural = .init(
                    lighting: lighting,
                    thickness: thickness,
                    evaluationIntervalSeconds: evaluationIntervalSeconds,
                    oscillationTimeSeconds: oscillationTimeSeconds,
                    elements: elements
                )
            } else {
                procedural = nil
            }
            _ = try cursor.readCString(allowEmpty: true)
            _ = try cursor.readFloat()
            try cursor.requireEnd()
            if !name.isEmpty {
                pages.append(
                    RetailTexturePage(
                        storedIndex: textureIndex,
                        name: name,
                        bitmapSourceName: bitmapSourceName,
                        lightColor: .init(x: red, y: green, z: blue),
                        coronaType: coronaType,
                        flags: flags,
                        alpha: alpha,
                        procedural: procedural
                    )
                )
            }
            textureIndex += 1
        }
        offset += 1 + length
    }
    return pages
}

private func canonicalTextureDefinition(
    _ page: RetailTexturePage
) throws -> RetailTextureDefinition {
    let isProcedural = page.flags & 0x0100_0000 != 0
    let isWater = page.flags & 0x0200_0000 != 0
    let isSaturated = page.flags & 0x0020_0000 != 0
    guard page.alpha.isFinite, (0...1).contains(page.alpha) else {
        throw RetailTextureTableError.unsupportedPresentation(page.name)
    }
    let lightCorona = try canonicalLightCorona(page)
    if isProcedural || isWater {
        guard isProcedural,
              isWater,
              isSaturated,
              let procedural = page.procedural,
              procedural.lighting <= 15,
              procedural.thickness < 16,
              procedural.evaluationIntervalSeconds.isFinite,
              procedural.evaluationIntervalSeconds >= 0,
              procedural.oscillationTimeSeconds == 0 else {
            throw RetailTextureTableError.unsupportedPresentation(page.name)
        }
        let elements = try procedural.elements.map { element in
            let kind: WaterProceduralElementKind
            switch element.type {
            case 0: kind = .noOp
            case 1: kind = .heightBlob
            default:
                throw RetailTextureTableError.unsupportedPresentation(page.name)
            }
            return WaterProceduralElement(
                kind: kind,
                frequency: element.frequency,
                speed: element.speed,
                size: element.size,
                x1: element.x1,
                y1: element.y1,
                x2: element.x2,
                y2: element.y2
            )
        }
        return RetailTextureDefinition(
            storedIndex: page.storedIndex,
            name: page.name,
            bitmapSourceName: page.bitmapSourceName,
            blend: .additiveSourceAlpha(opacity: UInt8(page.alpha * 255)),
            lightmapBlend: .none,
            waterProcedural: .init(
                evaluationIntervalSeconds: procedural.evaluationIntervalSeconds,
                lightingShift: 15 - procedural.lighting,
                dampingShift: procedural.thickness,
                elements: elements
            ),
            lightCorona: lightCorona,
        )
    }
    let usesConstantAlpha = page.flags & 0x0040_0000 != 0
    let blend: PresentationBlend
    if isSaturated {
        blend = .additiveSourceAlpha(opacity: UInt8(page.alpha * 255))
    } else if usesConstantAlpha {
        blend = .sourceAlpha(opacity: UInt8(page.alpha * 255))
    } else {
        blend = .opaque
    }
    return RetailTextureDefinition(
        storedIndex: page.storedIndex,
        name: page.name,
        bitmapSourceName: page.bitmapSourceName,
        blend: blend,
        lightmapBlend: blend == .opaque ? .multiply : .none,
        waterProcedural: nil,
        lightCorona: lightCorona,
    )
}

private func canonicalLightCorona(
    _ page: RetailTexturePage
) throws -> RetailLightCoronaDefinition? {
    guard page.flags & 0x0008_0000 != 0 else { return nil }
    guard page.coronaType == 0,
          page.lightColor.x.isFinite,
          page.lightColor.y.isFinite,
          page.lightColor.z.isFinite,
          page.lightColor.x >= 0,
          page.lightColor.y >= 0,
          page.lightColor.z >= 0 else {
        throw RetailTextureTableError.unsupportedPresentation(page.name)
    }
    let maximum = max(page.lightColor.x, page.lightColor.y, page.lightColor.z)
    let tint = maximum > 1
        ? Vector3(
            x: page.lightColor.x / maximum,
            y: page.lightColor.y / maximum,
            z: page.lightColor.z / maximum
        )
        : page.lightColor
    return RetailLightCoronaDefinition(
        bitmapSourceName: "StarFlare6.ogf",
        tint: tint,
        blend: .additiveSourceAlpha(opacity: 102)
    )
}

struct RetailSoundPageSelection: Equatable, Sendable {
    let storedIndex: Int
    let logicalName: String
    let sourceName: String
    let importVolume: Float
}

func resolveRetailSoundPage(
    table: Data,
    overlay: Data,
    named name: String
) throws -> RetailSoundPageSelection {
    let base = try parseRetailSoundPages(table)
    let replacements = try parseRetailSoundPages(overlay)
    var byName = Dictionary(
        uniqueKeysWithValues: base.map {
            ($0.logicalName.lowercased(), $0)
        }
    )
    var nextIndex = (base.map(\.storedIndex).max() ?? -1) + 1
    for replacement in replacements {
        let key = replacement.logicalName.lowercased()
        let storedIndex = byName[key]?.storedIndex ?? nextIndex
        if byName[key] == nil { nextIndex += 1 }
        byName[key] = .init(
            storedIndex: storedIndex,
            logicalName: replacement.logicalName,
            sourceName: replacement.sourceName,
            importVolume: replacement.importVolume
        )
    }
    guard let selected = byName[name.lowercased()] else {
        throw RetailTextureTableError.missingName(name)
    }
    return selected
}

private func parseRetailSoundPages(
    _ data: Data
) throws -> [RetailSoundPageSelection] {
    var offset = 0
    var pages: [RetailSoundPageSelection] = []
    var soundIndex = 0
    while offset < data.count {
        guard data.count - offset >= 5 else {
            throw RetailTextureTableError.truncated
        }
        let type = data[offset]
        let length = Int(readTableUInt32(data, at: offset + 1))
        guard length >= 4,
              length - 4 <= data.count - offset - 5 else {
            throw RetailTextureTableError.invalidPageLength
        }
        if type == 7 {
            var cursor = RetailPageCursor(
                Data(data[(offset + 5)..<(offset + 1 + length)])
            )
            guard try cursor.readUInt16() == 1 else {
                throw RetailTextureTableError.invalidPageLength
            }
            let logicalName = try cursor.readCString()
            let sourceName = try cursor.readCString()
            _ = try cursor.readInt32()
            _ = try cursor.readInt32()
            _ = try cursor.readInt32()
            _ = try cursor.readFloat()
            _ = try cursor.readInt32()
            _ = try cursor.readInt32()
            _ = try cursor.readFloat()
            _ = try cursor.readFloat()
            let importVolume = try cursor.readFloat()
            try cursor.requireEnd()
            guard importVolume.isFinite, importVolume >= 0 else {
                throw RetailTextureTableError.invalidPageLength
            }
            pages.append(.init(
                storedIndex: soundIndex,
                logicalName: logicalName,
                sourceName: sourceName,
                importVolume: importVolume
            ))
            soundIndex += 1
        }
        offset += 1 + length
    }
    return pages
}

private func readTableUInt32(_ data: Data, at offset: Int) -> UInt32 {
    UInt32(data[offset])
        | UInt32(data[offset + 1]) << 8
        | UInt32(data[offset + 2]) << 16
        | UInt32(data[offset + 3]) << 24
}

private struct RetailPageCursor {
    let data: Data
    var offset = 0

    var remaining: Int { data.count - offset }

    init(_ data: Data) { self.data = data }

    mutating func readUInt8() throws -> UInt8 {
        guard offset < data.count else { throw RetailTextureTableError.truncated }
        defer { offset += 1 }
        return data[offset]
    }

    mutating func readUInt16() throws -> UInt16 {
        UInt16(try readUInt8()) | UInt16(try readUInt8()) << 8
    }

    mutating func readUInt32() throws -> UInt32 {
        UInt32(try readUInt8())
            | UInt32(try readUInt8()) << 8
            | UInt32(try readUInt8()) << 16
            | UInt32(try readUInt8()) << 24
    }

    mutating func readInt32() throws -> Int32 {
        Int32(bitPattern: try readUInt32())
    }

    mutating func readFloat() throws -> Float {
        Float(bitPattern: try readUInt32())
    }

    mutating func readCString(allowEmpty: Bool = false) throws -> String {
        let start = offset
        while offset < data.count {
            if data[offset] == 0 {
                let bytes = data[start..<offset]
                offset += 1
                guard (allowEmpty || !bytes.isEmpty), bytes.allSatisfy({ $0 < 0x80 }) else {
                    throw RetailTextureTableError.invalidName
                }
                return String(decoding: bytes, as: UTF8.self)
            }
            offset += 1
        }
        throw RetailTextureTableError.truncated
    }

    mutating func skip(_ count: Int) throws {
        guard count >= 0, count <= data.count - offset else {
            throw RetailTextureTableError.truncated
        }
        offset += count
    }

    func requireEnd() throws {
        guard offset == data.count else {
            throw RetailTextureTableError.invalidPageLength
        }
    }
}

struct RetailModelPageSelection: Equatable, Sendable {
    let name: String
    let primaryModelName: String
    let mediumModelName: String?
    let lowModelName: String?
    let dyingModelName: String?
    let mediumDistance: Float?
    let lowDistance: Float?
    let shipDefinition: RetailShipDefinition?
    let genericLight: RetailGenericLightDefinition?
    let genericAI: RetailGenericAIDefinition?
}

struct RetailShipDefinition: Equatable, Sendable {
    let name: String
    let presentationSize: Float
    let physics: CanonicalShipPhysics
}

struct RetailGenericLightDefinition: Equatable, Sendable {
    let primaryColor: Vector3
    let secondaryColor: Vector3
    let timeInterval: Float
    let flickerDistance: Float
    let directionalDot: Float
    let flags: UInt32
    let timebits: UInt32
    let angle: UInt8
    let lightingRenderType: UInt8
}

struct RetailGenericAIDefinition: Equatable, Sendable {
    let objectSize: Float
    let flags: UInt32
    let movementType: UInt8
    let fieldOfView: Float
    let maximumVelocity: Float
    let maximumDeltaVelocity: Float
    let maximumTurnRate: Float
    let maximumDeltaTurnRate: Float
    let circleDistance: Float
}

struct ReachedObjectModelPages: Equatable, Sendable {
    let ship: RetailModelPageSelection
    let generic: RetailModelPageSelection
}

func resolveReachedObjectModelPages(
    table: Data,
    overlay: Data,
    shipName: String,
    genericName: String
) throws -> ReachedObjectModelPages {
    let base = try parseRetailModelPages(table)
    let overlayPages = try parseRetailModelPages(overlay)
    var pages = Dictionary(uniqueKeysWithValues: base.map { ($0.name.lowercased(), $0) })
    for page in overlayPages { pages[page.name.lowercased()] = page }
    guard let ship = pages[shipName.lowercased()], ship.dyingModelName != nil else {
        throw RetailTextureTableError.missingName(shipName)
    }
    guard let generic = pages[genericName.lowercased()], generic.dyingModelName == nil else {
        throw RetailTextureTableError.missingName(genericName)
    }
    return .init(ship: ship, generic: generic)
}

func resolveRetailGenericModelPage(
    table: Data,
    overlay: Data,
    name: String
) throws -> RetailModelPageSelection {
    let base = try parseRetailModelPages(table)
    let overlayPages = try parseRetailModelPages(overlay)
    var pages = Dictionary(
        uniqueKeysWithValues: base.map { ($0.name.lowercased(), $0) }
    )
    for page in overlayPages {
        pages[page.name.lowercased()] = page
    }
    guard let page = pages[name.lowercased()],
          page.shipDefinition == nil,
          page.dyingModelName == nil
    else {
        throw RetailTextureTableError.missingName(name)
    }
    return page
}

private func parseRetailModelPages(_ data: Data) throws -> [RetailModelPageSelection] {
    var offset = 0
    var pages: [RetailModelPageSelection] = []
    while offset < data.count {
        guard data.count - offset >= 5 else { throw RetailTextureTableError.truncated }
        let type = data[offset]
        let length = Int(readTableUInt32(data, at: offset + 1))
        guard length >= 4, length - 4 <= data.count - offset - 5 else {
            throw RetailTextureTableError.invalidPageLength
        }
        if type == 6 || type == 10 {
            let body = Data(data[(offset + 5)..<(offset + 1 + length)])
            var cursor = RetailPageCursor(body)
            let version = Int(try cursor.readUInt16())
            if type == 6 {
                let name = try cursor.readCString()
                _ = try cursor.readCString(allowEmpty: true)
                _ = try cursor.readCString(allowEmpty: true)
                let primary = try cursor.readCString()
                let dying = try cursor.readCString()
                let medium = try cursor.readCString(allowEmpty: true)
                let low = try cursor.readCString(allowEmpty: true)
                let mediumDistance = try cursor.readFloat()
                let lowDistance = try cursor.readFloat()
                let physics = try cursor.readCanonicalShipPhysics()
                let presentationSize = try cursor.readFloat()
                _ = try cursor.readFloat()
                _ = try cursor.readInt32()
                guard version >= 1,
                      mediumDistance.isFinite,
                      lowDistance.isFinite,
                      mediumDistance > 0,
                      lowDistance > mediumDistance,
                      presentationSize.isFinite,
                      presentationSize > 0 else {
                    throw RetailTextureTableError.unsupportedPresentation(name)
                }
                pages.append(
                    .init(
                        name: name,
                        primaryModelName: primary,
                        mediumModelName: medium.isEmpty ? nil : medium,
                        lowModelName: low.isEmpty ? nil : low,
                        dyingModelName: dying,
                        mediumDistance: medium.isEmpty ? nil : mediumDistance,
                        lowDistance: low.isEmpty ? nil : lowDistance,
                        shipDefinition: .init(
                            name: name,
                            presentationSize: presentationSize,
                            physics: physics
                        ),
                        genericLight: nil,
                        genericAI: nil
                    )
                )
            } else {
                let objectType = try cursor.readUInt8()
                let name = try cursor.readCString()
                let primary = try cursor.readCString()
                let medium = try cursor.readCString(allowEmpty: true)
                let low = try cursor.readCString(allowEmpty: true)
                try cursor.skip(12)
                try cursor.skip(version >= 24 ? 2 : 1)
                if objectType == 7, version >= 25 { try cursor.skip(2) }
                _ = try cursor.readCString(allowEmpty: true)
                if version >= 18 { _ = try cursor.readCString(allowEmpty: true) }
                if version >= 19 { _ = try cursor.readCString(allowEmpty: true) }
                if try cursor.readUInt8() != 0 {
                    _ = try cursor.readCString(allowEmpty: true)
                }
                _ = try cursor.readCString(allowEmpty: true)
                let mediumDistance = try cursor.readFloat()
                let lowDistance = try cursor.readFloat()
                try cursor.skip(68)
                let objectSize = try cursor.readFloat()
                _ = try cursor.readFloat()
                let primaryColor = Vector3(
                    x: try cursor.readFloat(),
                    y: try cursor.readFloat(),
                    z: try cursor.readFloat()
                )
                let timeInterval = try cursor.readFloat()
                let flickerDistance = try cursor.readFloat()
                let directionalDot = try cursor.readFloat()
                let secondaryColor = Vector3(
                    x: try cursor.readFloat(),
                    y: try cursor.readFloat(),
                    z: try cursor.readFloat()
                )
                let flags = try cursor.readUInt32()
                let timebits = try cursor.readUInt32()
                let angle = try cursor.readUInt8()
                let lightingRenderType = try cursor.readUInt8()
                _ = try cursor.readInt32()
                _ = try cursor.readUInt32()
                let aiFlags = try cursor.readUInt32()
                _ = try cursor.readUInt8()
                _ = try cursor.readUInt8()
                let movementType = try cursor.readUInt8()
                _ = try cursor.readUInt8()
                let fieldOfView = try cursor.readFloat()
                let maximumVelocity = try cursor.readFloat()
                let maximumDeltaVelocity = try cursor.readFloat()
                let maximumTurnRate = try cursor.readFloat()
                _ = try cursor.readUInt32()
                let maximumDeltaTurnRate = try cursor.readFloat()
                let circleDistance = try cursor.readFloat()
                guard version >= 1,
                      mediumDistance.isFinite,
                      lowDistance.isFinite,
                      objectSize.isFinite,
                      objectSize > 0,
                      primaryColor.x.isFinite,
                      primaryColor.y.isFinite,
                      primaryColor.z.isFinite,
                      secondaryColor.x.isFinite,
                      secondaryColor.y.isFinite,
                      secondaryColor.z.isFinite,
                      timeInterval.isFinite,
                      flickerDistance.isFinite,
                      directionalDot.isFinite,
                      fieldOfView.isFinite,
                      maximumVelocity.isFinite,
                      maximumDeltaVelocity.isFinite,
                      maximumTurnRate.isFinite,
                      maximumDeltaTurnRate.isFinite,
                      circleDistance.isFinite else {
                    throw RetailTextureTableError.unsupportedPresentation(name)
                }
                pages.append(
                    .init(
                        name: name,
                        primaryModelName: primary,
                        mediumModelName: medium.isEmpty ? nil : medium,
                        lowModelName: low.isEmpty ? nil : low,
                        dyingModelName: nil,
                        mediumDistance: medium.isEmpty ? nil : mediumDistance,
                        lowDistance: low.isEmpty ? nil : lowDistance,
                        shipDefinition: nil,
                        genericLight: .init(
                            primaryColor: primaryColor,
                            secondaryColor: secondaryColor,
                            timeInterval: timeInterval,
                            flickerDistance: flickerDistance,
                            directionalDot: directionalDot,
                            flags: flags,
                            timebits: timebits,
                            angle: angle,
                            lightingRenderType: lightingRenderType
                        ),
                        genericAI: .init(
                            objectSize: objectSize,
                            flags: aiFlags,
                            movementType: movementType,
                            fieldOfView: fieldOfView,
                            maximumVelocity: maximumVelocity,
                            maximumDeltaVelocity:
                                maximumDeltaVelocity,
                            maximumTurnRate: maximumTurnRate,
                            maximumDeltaTurnRate:
                                maximumDeltaTurnRate,
                            circleDistance: circleDistance
                        )
                    )
                )
            }
        }
        offset += 1 + length
    }
    return pages
}

private extension RetailPageCursor {
    mutating func readCanonicalShipPhysics() throws -> CanonicalShipPhysics {
        let mass = try readFloat()
        let drag = try readFloat()
        let fullThrust = try readFloat()
        let rawFlags = try readUInt32()
        let supportedFlags: UInt32 = 0x01 | 0x08 | 0x40
        guard rawFlags & ~supportedFlags == 0 else {
            throw RetailTextureTableError.unsupportedPresentation("ship physics flags")
        }
        var behaviors: [ShipPhysicsBehavior] = []
        if rawFlags & 0x01 != 0 { behaviors.append(.turnroll) }
        if rawFlags & 0x08 != 0 { behaviors.append(.wiggle) }
        if rawFlags & 0x40 != 0 { behaviors.append(.usesThrust) }
        let rotationalDrag = try readFloat()
        let fullRotationalThrust = try readFloat()
        let numberOfBounces = try readInt32()
        let initialForwardVelocity = try readFloat()
        let initialAngularVelocity = Vector3(
            x: try readFloat(),
            y: try readFloat(),
            z: try readFloat()
        )
        let wiggleAmplitude = try readFloat()
        let wigglesPerSecond = try readFloat()
        let coefficientOfRestitution = try readFloat()
        let hitDieDot = try readFloat()
        let maximumTurnrollRate = try readFloat()
        let turnrollRatio = try readFloat()
        let finite = [
            mass, drag, fullThrust, rotationalDrag, fullRotationalThrust,
            initialForwardVelocity, initialAngularVelocity.x,
            initialAngularVelocity.y, initialAngularVelocity.z,
            wiggleAmplitude, wigglesPerSecond, coefficientOfRestitution,
            hitDieDot, maximumTurnrollRate, turnrollRatio,
        ].allSatisfy(\.isFinite)
        guard finite else {
            throw RetailTextureTableError.unsupportedPresentation("ship physics")
        }
        return CanonicalShipPhysics(
            mass: mass,
            drag: drag,
            fullThrust: fullThrust,
            behaviors: behaviors,
            rotationalDrag: rotationalDrag,
            fullRotationalThrust: fullRotationalThrust,
            numberOfBounces: numberOfBounces,
            initialForwardVelocity: initialForwardVelocity,
            initialAngularVelocity: initialAngularVelocity,
            wiggleAmplitude: wiggleAmplitude,
            wigglesPerSecond: wigglesPerSecond,
            coefficientOfRestitution: coefficientOfRestitution,
            hitDieDot: hitDieDot,
            maximumTurnrollRate: maximumTurnrollRate,
            turnrollRatio: turnrollRatio
        )
    }
}

enum OutrageModelImportError: Error, Equatable {
    case truncated
    case invalidHeader
    case unsupportedVersion(Int)
    case invalidChunk(String)
    case invalidCount(String)
    case invalidIndex(String)
    case invalidString
    case missingChunk(String)
    case geometryFree
    case unsupportedPresentation(String)
}

func reachedOutrageModelTextureNames(_ data: Data) throws -> [String] {
    var cursor = OutrageModelCursor(data)
    guard try cursor.readASCII(4) == "PSPO" else {
        throw OutrageModelImportError.invalidHeader
    }
    var version = Int(try cursor.readInt32())
    if version < 18 { version *= 100 }
    guard version == 2_300 else { throw OutrageModelImportError.unsupportedVersion(version) }
    while !cursor.isAtEnd {
        let chunkName = try cursor.readASCII(4)
        let byteCount = try cursor.readCount(maximum: cursor.remaining, name: chunkName)
        var chunk = try cursor.readSubcursor(byteCount)
        guard chunkName == "TXTR" else { continue }
        let count = try chunk.readCount(maximum: 256, name: "texture slots")
        var names: [String] = []
        names.reserveCapacity(count)
        for _ in 0..<count { names.append(try chunk.readModelString(allowEmpty: false)) }
        try chunk.requireEnd(chunkName)
        return names
    }
    throw OutrageModelImportError.missingChunk("TXTR")
}

func reachedOutrageModelReferencedTextureSlotIndices(_ data: Data) throws -> Set<Int> {
    let names = try reachedOutrageModelTextureNames(data)
    let placeholders = names.enumerated().map {
        SourceResource(storedIndex: $0.offset, sourceName: $0.element)
    }
    let model = try parseReachedOutrageModel(
        data,
        sourceName: "dependency-probe.OOF",
        sourceArchive: "d3.hog",
        textureResources: placeholders.map(Optional.some)
    )
    return Set(model.submodels.flatMap { submodel in
        submodel.faces.compactMap { face in
            if case .texture(let source) = face.material { return source.storedIndex }
            return nil
        }
    })
}

struct ReachedModelGunpoint: Equatable, Sendable {
    let parentSubmodelIndex: Int
    let localPosition: Vector3
    let position: Vector3
    let forward: Vector3

    init(
        parentSubmodelIndex: Int,
        position: Vector3,
        forward: Vector3
    ) {
        self.parentSubmodelIndex = parentSubmodelIndex
        localPosition = position
        self.position = position
        self.forward = forward
    }

    init(
        parentSubmodelIndex: Int,
        localPosition: Vector3,
        position: Vector3,
        forward: Vector3
    ) {
        self.parentSubmodelIndex = parentSubmodelIndex
        self.localPosition = localPosition
        self.position = position
        self.forward = forward
    }
}

func reachedOutrageModelGunpoint(
    _ data: Data,
    index: Int
) throws -> ReachedModelGunpoint {
    var cursor = OutrageModelCursor(data)
    guard try cursor.readASCII(4) == "PSPO" else {
        throw OutrageModelImportError.invalidHeader
    }
    var version = Int(try cursor.readInt32())
    if version < 18 { version *= 100 }
    guard version == 2_300 else {
        throw OutrageModelImportError.unsupportedVersion(version)
    }
    var rawGunpoint: ReachedModelGunpoint?
    var submodelOffsets: [Int: (
        parent: Int?,
        offset: Vector3
    )] = [:]
    while !cursor.isAtEnd {
        let name = try cursor.readASCII(4)
        let count = try cursor.readCount(
            maximum: cursor.remaining,
            name: name
        )
        var chunk = try cursor.readSubcursor(count)
        if name == "SOBJ" {
            let sourceIndex = Int(try chunk.readInt32())
            let rawParent = Int(try chunk.readInt32())
            _ = try chunk.readVector()
            _ = try chunk.readFloat()
            _ = try chunk.readVector()
            let offset = try chunk.readVector()
            submodelOffsets[sourceIndex] = (
                rawParent < 0 ? nil : rawParent,
                offset
            )
        } else if name == "GPNT" {
            let gunpointCount = try chunk.readCount(
                maximum: 1_000,
                name: "gunpoints"
            )
            guard (0..<gunpointCount).contains(index) else {
                throw OutrageModelImportError.invalidIndex("gunpoint")
            }
            for gunpointIndex in 0..<gunpointCount {
                let parent = Int(try chunk.readInt32())
                let position = try chunk.readVector()
                let forward = try chunk.readVector()
                if gunpointIndex == index {
                    rawGunpoint = .init(
                        parentSubmodelIndex: parent,
                        localPosition: position,
                        position: position,
                        forward: forward
                    )
                }
            }
            try chunk.requireEnd(name)
        }
    }
    guard let rawGunpoint,
          submodelOffsets[rawGunpoint.parentSubmodelIndex] != nil else {
        throw OutrageModelImportError.missingChunk("GPNT")
    }
    var accumulated = Vector3.zero
    var current: Int? = rawGunpoint.parentSubmodelIndex
    var visited = Set<Int>()
    while let index = current {
        guard let submodel = submodelOffsets[index],
              visited.insert(index).inserted else {
            throw OutrageModelImportError.invalidIndex(
                "gunpoint parent"
            )
        }
        accumulated = addModelVectors(accumulated, submodel.offset)
        current = submodel.parent
    }
    let magnitude = sqrt(
        rawGunpoint.forward.x * rawGunpoint.forward.x
            + rawGunpoint.forward.y * rawGunpoint.forward.y
            + rawGunpoint.forward.z * rawGunpoint.forward.z
    )
    guard magnitude.isFinite, magnitude > 0 else {
        throw OutrageModelImportError.invalidChunk("GPNT")
    }
    return .init(
        parentSubmodelIndex: rawGunpoint.parentSubmodelIndex,
        localPosition: rawGunpoint.localPosition,
        position: addModelVectors(accumulated, rawGunpoint.position),
        forward: .init(
            x: rawGunpoint.forward.x / magnitude,
            y: rawGunpoint.forward.y / magnitude,
            z: rawGunpoint.forward.z / magnitude
        )
    )
}

func parseReachedOutrageModel(
    _ data: Data,
    sourceName: String,
    sourceIndex: Int = 0,
    sourceArchive: String,
    textureResources: [SourceResource?]
) throws -> CanonicalModel {
    var cursor = OutrageModelCursor(data)
    guard try cursor.readASCII(4) == "PSPO" else {
        throw OutrageModelImportError.invalidHeader
    }
    var version = Int(try cursor.readInt32())
    if version < 18 { version *= 100 }
    guard (2_300...2_300).contains(version) else {
        throw OutrageModelImportError.unsupportedVersion(version)
    }
    var declaredSubmodelCount: Int?
    var collisionRadius: Float?
    var textureNames: [String]?
    var submodels: [ModelSubmodel] = []
    var rotationAxes: [Int: Vector3] = [:]
    while !cursor.isAtEnd {
        let chunkName = try cursor.readASCII(4)
        let byteCount = try cursor.readCount(maximum: cursor.remaining, name: chunkName)
        var chunk = try cursor.readSubcursor(byteCount)
        switch chunkName {
        case "OHDR":
            declaredSubmodelCount = try chunk.readCount(maximum: 1_000, name: "submodels")
            collisionRadius = try chunk.readFloat()
            _ = try chunk.readVector()
            _ = try chunk.readVector()
            let detailCount = try chunk.readCount(maximum: 32, name: "detail levels")
            for _ in 0..<detailCount { _ = try chunk.readInt32() }
            try chunk.requireEnd(chunkName)
        case "TXTR":
            let count = try chunk.readCount(maximum: 256, name: "texture slots")
            var names: [String] = []
            names.reserveCapacity(count)
            for _ in 0..<count { names.append(try chunk.readModelString(allowEmpty: false)) }
            try chunk.requireEnd(chunkName)
            textureNames = names
        case "SOBJ":
            submodels.append(
                try parseReachedSubmodel(
                    &chunk,
                    version: version,
                    textureResources: textureResources
                )
            )
            try chunk.requireEnd(chunkName)
        case "RANI":
            guard let declaredSubmodelCount else {
                throw OutrageModelImportError.missingChunk("OHDR")
            }
            for submodelIndex in 0..<declaredSubmodelCount {
                let keyframeCount = try chunk.readCount(
                    maximum: 100_000,
                    name: "rotation keyframes"
                )
                _ = try chunk.readInt32()
                _ = try chunk.readInt32()
                for keyframeIndex in 0..<keyframeCount {
                    _ = try chunk.readInt32()
                    let axis = try chunk.readVector()
                    _ = try chunk.readInt32()
                    if keyframeIndex == 1 {
                        let magnitude = sqrt(
                            axis.x * axis.x + axis.y * axis.y
                                + axis.z * axis.z
                        )
                        guard magnitude.isFinite, magnitude > 0 else {
                            throw OutrageModelImportError.invalidChunk("RANI")
                        }
                        rotationAxes[submodelIndex] = .init(
                            x: axis.x / magnitude,
                            y: axis.y / magnitude,
                            z: axis.z / magnitude
                        )
                    }
                }
            }
            try chunk.requireEnd(chunkName)
        default:
            break
        }
    }
    guard let declaredSubmodelCount, let collisionRadius,
          collisionRadius.isFinite, collisionRadius > 0 else {
        throw OutrageModelImportError.missingChunk("OHDR")
    }
    guard let textureNames else {
        throw OutrageModelImportError.missingChunk("TXTR")
    }
    guard textureNames.count == textureResources.count,
          submodels.count == declaredSubmodelCount,
          Set(submodels.map(\.sourceIndex)) == Set(0..<declaredSubmodelCount) else {
        throw OutrageModelImportError.invalidCount("model closure")
    }
    let sortedSubmodels = try submodels.sorted {
        $0.sourceIndex < $1.sourceIndex
    }.map { submodel in
        let presentation: ModelSubmodelPresentation
        if case let .rotate(rate, _) = submodel.presentation {
            guard let axis = rotationAxes[submodel.sourceIndex] else {
                throw OutrageModelImportError.missingChunk(
                    "RANI rotation axis"
                )
            }
            presentation = .rotate(rate: rate, axis: axis)
        } else if case .turret(
            let
                fieldOfView,
            let
                rotationsPerSecond,
            let
                thinkInterval,
            _
        ) = submodel.presentation {
            guard let axis = rotationAxes[submodel.sourceIndex] else {
                throw OutrageModelImportError.missingChunk(
                    "RANI turret axis"
                )
            }
            presentation = .turret(
                fieldOfView: fieldOfView,
                rotationsPerSecond: rotationsPerSecond,
                thinkInterval: thinkInterval,
                axis: axis
            )
        } else {
            presentation = submodel.presentation
        }
        return ModelSubmodel(
            sourceIndex: submodel.sourceIndex,
            parentIndex: submodel.parentIndex,
            offset: submodel.offset,
            vertices: submodel.vertices,
            faces: submodel.faces,
            presentation: presentation
        )
    }
    var accumulatedOffsets = [Vector3?](repeating: nil, count: sortedSubmodels.count)
    func resolvedOffset(_ index: Int, visiting: inout Set<Int>) throws -> Vector3 {
        if let resolved = accumulatedOffsets[index] { return resolved }
        guard visiting.insert(index).inserted else {
            throw OutrageModelImportError.invalidIndex("submodel hierarchy")
        }
        let submodel = sortedSubmodels[index]
        let parentOffset: Vector3
        if let parent = submodel.parentIndex {
            guard sortedSubmodels.indices.contains(parent) else {
                throw OutrageModelImportError.invalidIndex("submodel parent")
            }
            parentOffset = try resolvedOffset(parent, visiting: &visiting)
        } else {
            parentOffset = .zero
        }
        visiting.remove(index)
        let result = addModelVectors(parentOffset, submodel.offset)
        accumulatedOffsets[index] = result
        return result
    }
    var bounds: ModelBounds?
    for submodel in sortedSubmodels {
        var visiting: Set<Int> = []
        let offset = try resolvedOffset(submodel.sourceIndex, visiting: &visiting)
        for vertex in submodel.vertices {
            bounds = expandModelBounds(bounds, addModelVectors(offset, vertex.position))
        }
    }
    guard let bounds else { throw OutrageModelImportError.geometryFree }
    return CanonicalModel(
        source: .init(storedIndex: sourceIndex, sourceName: sourceName),
        collisionRadius: collisionRadius,
        submodels: sortedSubmodels,
        bounds: bounds,
        sourceArchive: sourceArchive,
        sourceSHA256: canonicalSHA256(data)
    )
}

private func parseReachedSubmodel(
    _ cursor: inout OutrageModelCursor,
    version: Int,
    textureResources: [SourceResource?]
) throws -> ModelSubmodel {
    let sourceIndex = Int(try cursor.readInt32())
    let rawParent = Int(try cursor.readInt32())
    _ = try cursor.readVector()
    _ = try cursor.readFloat()
    _ = try cursor.readVector()
    let offset = try cursor.readVector()
    _ = try cursor.readFloat()
    _ = try cursor.readInt32()
    _ = try cursor.readInt32()
    if version > 1_805 { _ = try cursor.readVector() }
    _ = try cursor.readModelString(allowEmpty: true)
    let properties = try cursor.readModelString(allowEmpty: true)
    _ = try cursor.readInt32()
    _ = try cursor.readInt32()
    let freeChunkCount = try cursor.readCount(maximum: 10_000, name: "free chunks")
    for _ in 0..<freeChunkCount { _ = try cursor.readInt32() }
    let vertexCount = try cursor.readCount(maximum: 100_000, name: "vertices")
    var positions: [Vector3] = []
    positions.reserveCapacity(vertexCount)
    for _ in 0..<vertexCount { positions.append(try cursor.readVector()) }
    for _ in 0..<vertexCount { _ = try cursor.readVector() }
    var alphas = [Float](repeating: 1, count: vertexCount)
    if version / 100 >= 23 {
        for index in alphas.indices { alphas[index] = try cursor.readFloat() }
    }
    let vertices = positions.indices.map { ModelVertex(position: positions[$0], alpha: alphas[$0]) }
    let faceCount = try cursor.readCount(maximum: 100_000, name: "faces")
    var faces: [ModelFace] = []
    faces.reserveCapacity(faceCount)
    for _ in 0..<faceCount {
        let normal = try cursor.readVector()
        let cornerCount = try cursor.readCount(maximum: 100_000, name: "face vertices")
        guard cornerCount >= 3 else { throw OutrageModelImportError.invalidCount("face vertices") }
        let textured = try cursor.readInt32() != 0
        let material: ModelFaceMaterial
        if textured {
            let slot = Int(try cursor.readInt32())
            guard textureResources.indices.contains(slot),
                  let texture = textureResources[slot] else {
                throw OutrageModelImportError.invalidIndex("missing texture slot")
            }
            material = .texture(texture)
        } else {
            material = .sourceColor(
                red: try cursor.readUInt8(),
                green: try cursor.readUInt8(),
                blue: try cursor.readUInt8()
            )
        }
        var corners: [ModelFaceCorner] = []
        corners.reserveCapacity(cornerCount)
        for _ in 0..<cornerCount {
            let vertexIndex = Int(try cursor.readInt32())
            guard vertices.indices.contains(vertexIndex) else {
                throw OutrageModelImportError.invalidIndex("face vertex")
            }
            corners.append(
                .init(vertexIndex: vertexIndex, u: try cursor.readFloat(), v: try cursor.readFloat())
            )
        }
        if version / 100 >= 21 {
            _ = try cursor.readFloat()
            _ = try cursor.readFloat()
        }
        faces.append(.init(normal: normal, corners: corners, material: material))
    }
    return .init(
        sourceIndex: sourceIndex,
        parentIndex: rawParent < 0 ? nil : rawParent,
        offset: offset,
        vertices: vertices,
        faces: faces,
        presentation: try parseSubmodelPresentation(properties)
    )
}

private func parseSubmodelPresentation(_ properties: String) throws -> ModelSubmodelPresentation {
    let lower = properties.lowercased()
    if lower == "$custom" { return .custom }
    if lower.hasPrefix("$facing") { return .facing }
    if lower.hasPrefix("$fov=") {
        let values = properties.dropFirst("$fov=".count)
            .split(separator: ",")
            .compactMap {
                Float(
                    $0.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                )
            }
        guard values.count == 3,
            values.allSatisfy(\.isFinite),
            (0...360).contains(values[0]),
            values[1] > 0,
            values[2] >= 0
        else {
            throw OutrageModelImportError.invalidString
        }
        return .turret(
            fieldOfView: values[0] / 720,
            rotationsPerSecond: 1 / values[1],
            thinkInterval: values[2],
            axis: .zero
        )
    }
    if lower.hasPrefix("$rotate="),
       let rate = Float(
           lower.dropFirst("$rotate=".count)
               .trimmingCharacters(in: .whitespacesAndNewlines)
       ),
       rate.isFinite {
        return .rotate(rate: rate, axis: .zero)
    }
    if lower.hasPrefix("$glow=") {
        let values = properties.dropFirst("$glow=".count).split(separator: ",").compactMap {
            Float($0.trimmingCharacters(in: .whitespaces))
        }
        guard values.count == 4, values.allSatisfy(\.isFinite), values[3] > 0 else {
            throw OutrageModelImportError.invalidString
        }
        return .glow(
            color: .init(x: values[0], y: values[1], z: values[2]),
            size: values[3]
        )
    }
    if lower.hasPrefix("$") {
        throw OutrageModelImportError.unsupportedPresentation(properties)
    }
    return .standard
}

private struct OutrageModelCursor {
    let data: Data
    var offset = 0
    var remaining: Int { data.count - offset }
    var isAtEnd: Bool { offset == data.count }

    init(_ data: Data) { self.data = data }

    mutating func readUInt8() throws -> UInt8 {
        guard remaining >= 1 else { throw OutrageModelImportError.truncated }
        defer { offset += 1 }
        return data[offset]
    }

    mutating func readInt32() throws -> Int32 {
        let value = UInt32(try readUInt8())
            | UInt32(try readUInt8()) << 8
            | UInt32(try readUInt8()) << 16
            | UInt32(try readUInt8()) << 24
        return Int32(bitPattern: value)
    }

    mutating func readFloat() throws -> Float {
        Float(bitPattern: UInt32(bitPattern: try readInt32()))
    }

    mutating func readVector() throws -> Vector3 {
        .init(x: try readFloat(), y: try readFloat(), z: try readFloat())
    }

    mutating func readCount(maximum: Int, name: String) throws -> Int {
        let value = Int(try readInt32())
        guard value >= 0, value <= maximum else {
            throw OutrageModelImportError.invalidCount(name)
        }
        return value
    }

    mutating func readASCII(_ count: Int) throws -> String {
        guard count >= 0, remaining >= count else { throw OutrageModelImportError.truncated }
        let bytes = data[offset..<(offset + count)]
        offset += count
        guard bytes.allSatisfy({ $0 >= 0x20 && $0 < 0x7f }) else {
            throw OutrageModelImportError.invalidString
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    mutating func readModelString(allowEmpty: Bool) throws -> String {
        let count = try readCount(maximum: 4_096, name: "string")
        guard count > 0, remaining >= count else { throw OutrageModelImportError.invalidString }
        let bytes = data[offset..<(offset + count)]
        offset += count
        guard bytes.last == 0,
              bytes.dropLast().allSatisfy({ $0 < 0x80 }),
              allowEmpty || count > 1 else {
            throw OutrageModelImportError.invalidString
        }
        return String(decoding: bytes.dropLast(), as: UTF8.self)
    }

    mutating func readSubcursor(_ count: Int) throws -> OutrageModelCursor {
        guard count >= 0, remaining >= count else { throw OutrageModelImportError.truncated }
        defer { offset += count }
        return .init(Data(data[offset..<(offset + count)]))
    }

    func requireEnd(_ chunk: String) throws {
        guard isAtEnd else { throw OutrageModelImportError.invalidChunk(chunk) }
    }
}

private func addModelVectors(_ lhs: Vector3, _ rhs: Vector3) -> Vector3 {
    .init(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
}

private func expandModelBounds(_ bounds: ModelBounds?, _ point: Vector3) -> ModelBounds {
    guard let bounds else { return .init(minimum: point, maximum: point) }
    return .init(
        minimum: .init(
            x: min(bounds.minimum.x, point.x),
            y: min(bounds.minimum.y, point.y),
            z: min(bounds.minimum.z, point.z)
        ),
        maximum: .init(
            x: max(bounds.maximum.x, point.x),
            y: max(bounds.maximum.y, point.y),
            z: max(bounds.maximum.z, point.z)
        )
    )
}

func decodeReachedOutrage16OGF(_ data: Data) throws -> Outrage1555Image {
    var cursor = OGFByteCursor(data)
    let imageIdentifierLength = Int(try cursor.readUInt8())
    guard try cursor.readUInt8() == 0 else {
        throw Outrage1555DecodeError.unsupportedHeader
    }
    let imageType = try cursor.readUInt8()
    let pixelFormat: LegacyOGFPixelFormat
    switch imageType {
    case 121: pixelFormat = .argb4444
    case 122: pixelFormat = .argb1555
    default: throw Outrage1555DecodeError.unsupportedHeader
    }
    _ = try cursor.readCString(maximumByteCount: 35)
    let mipCount = Int(try cursor.readUInt8())
    guard mipCount > 0 else { throw Outrage1555DecodeError.unsupportedHeader }
    try cursor.skip(9)
    let width = Int(try cursor.readUInt16())
    let height = Int(try cursor.readUInt16())
    guard (1...256).contains(width), (1...256).contains(height) else {
        throw Outrage1555DecodeError.invalidDimensions
    }
    guard try cursor.readUInt8() == 32, try cursor.readUInt8() & 0x0f == 8 else {
        throw Outrage1555DecodeError.unsupportedHeader
    }
    try cursor.skip(imageIdentifierLength)

    var firstMip: [UInt16] = []
    for mip in 0..<mipCount {
        let mipWidth = max(1, width >> mip)
        let mipHeight = max(1, height >> mip)
        let pixelCount = mipWidth * mipHeight
        var pixels: [UInt16] = []
        pixels.reserveCapacity(pixelCount)
        while pixels.count < pixelCount {
            let command = try cursor.readUInt8()
            guard command == 0 || (2...250).contains(command) else {
                throw Outrage1555DecodeError.invalidRun
            }
            let pixel = try cursor.readUInt16()
            let count = command == 0 ? 1 : Int(command)
            guard count <= pixelCount - pixels.count else {
                throw Outrage1555DecodeError.invalidRun
            }
            pixels.append(contentsOf: repeatElement(pixel, count: count))
        }
        if mip == 0 { firstMip = pixels }
    }
    guard cursor.isAtEnd else { throw Outrage1555DecodeError.trailingBytes }
    return Outrage1555Image(
        width: width,
        height: height,
        rgba8: canonicalRGBA8(firstMip, format: pixelFormat),
        sourceWasARGB4444: pixelFormat == .argb4444
    )
}

private func canonicalRGBA8(
    _ pixels: [UInt16],
    format: LegacyOGFPixelFormat
) -> Data {
    var rgba8 = Data()
    rgba8.reserveCapacity(pixels.count * 4)
    for pixel in pixels {
        switch format {
        case .argb1555:
            rgba8.append(expandFiveBits(UInt8((pixel >> 10) & 0x1f)))
            rgba8.append(expandFiveBits(UInt8((pixel >> 5) & 0x1f)))
            rgba8.append(expandFiveBits(UInt8(pixel & 0x1f)))
            rgba8.append(pixel & 0x8000 == 0 ? 0 : 255)
        case .argb4444:
            rgba8.append(expandFourBits(UInt8((pixel >> 8) & 0x0f)))
            rgba8.append(expandFourBits(UInt8((pixel >> 4) & 0x0f)))
            rgba8.append(expandFourBits(UInt8(pixel & 0x0f)))
            rgba8.append(expandFourBits(UInt8((pixel >> 12) & 0x0f)))
        }
    }
    return rgba8
}

func canonicalRGBA8From1555(_ pixels: [UInt16]) -> Data {
    canonicalRGBA8(pixels, format: .argb1555)
}

private func expandFiveBits(_ value: UInt8) -> UInt8 {
    value << 3 | value >> 2
}

private func expandFourBits(_ value: UInt8) -> UInt8 {
    value << 4 | value
}

private struct OGFByteCursor {
    private let data: Data
    private(set) var offset = 0

    init(_ data: Data) {
        self.data = data
    }

    var isAtEnd: Bool { offset == data.count }

    mutating func readUInt8() throws -> UInt8 {
        guard offset < data.count else { throw Outrage1555DecodeError.truncated }
        defer { offset += 1 }
        return data[offset]
    }

    mutating func readUInt16() throws -> UInt16 {
        let low = UInt16(try readUInt8())
        return low | UInt16(try readUInt8()) << 8
    }

    mutating func readCString(maximumByteCount: Int) throws -> String {
        let start = offset
        while offset < data.count, offset - start <= maximumByteCount {
            if data[offset] == 0 {
                let bytes = data[start..<offset]
                offset += 1
                guard !bytes.isEmpty,
                      bytes.allSatisfy({ $0 < 0x80 }) else {
                    throw Outrage1555DecodeError.invalidName
                }
                return String(decoding: bytes, as: UTF8.self)
            }
            offset += 1
        }
        throw Outrage1555DecodeError.invalidName
    }

    mutating func skip(_ count: Int) throws {
        guard count >= 0, count <= data.count - offset else {
            throw Outrage1555DecodeError.truncated
        }
        offset += count
    }
}
