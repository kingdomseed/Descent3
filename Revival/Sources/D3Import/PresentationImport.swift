// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

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
    let name: String
    let bitmapSourceName: String
    let blend: PresentationBlend
    let lightmapBlend: PresentationLightmapBlend
    let waterProcedural: WaterProceduralDefinition?
    let lightCorona: RetailLightCoronaDefinition?
    let requiresARGB4444ForOpaqueTMap2: Bool
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
    let basePages = try parseRetailTexturePages(table)
    let overlayPages = try parseRetailTexturePages(overlay)
    var pageByName: [String: RetailTexturePage] = [:]
    for page in basePages {
        let key = page.name.lowercased()
        guard pageByName[key] == nil else { continue }
        pageByName[key] = page
    }
    for page in overlayPages {
        pageByName[page.name.lowercased()] = page
    }
    return try requestedNames.sorted().map { name in
        guard let page = pageByName[name.lowercased()] else {
            throw RetailTextureTableError.missingName(name)
        }
        return try canonicalTextureDefinition(page)
    }
}

private struct RetailTexturePage {
    let name: String
    let bitmapSourceName: String
    let lightColor: Vector3
    let coronaType: UInt8
    let flags: UInt32
    let alpha: Float
    let procedural: RetailProceduralPage?
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
            requiresARGB4444ForOpaqueTMap2: false
        )
    }
    guard page.alpha >= 0.9999,
          page.flags & 0x0040_0000 == 0,
          page.flags & 0x0020_0000 == 0 else {
        throw RetailTextureTableError.unsupportedPresentation(page.name)
    }
    return RetailTextureDefinition(
        name: page.name,
        bitmapSourceName: page.bitmapSourceName,
        blend: .opaque,
        lightmapBlend: .multiply,
        waterProcedural: nil,
        lightCorona: lightCorona,
        requiresARGB4444ForOpaqueTMap2: page.flags & 0x0000_4000 != 0
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
