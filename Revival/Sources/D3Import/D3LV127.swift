// SPDX-License-Identifier: GPL-3.0-or-later
//
// Source provenance: Descent3/LoadLevel.cpp ReadHeader and top-level chunk loop.

import Foundation

struct D3LV127Chunk: Equatable, Sendable {
    let name: String
    let payloadRange: Range<Int>
}

enum D3LV127Error: Error, Equatable {
    case truncatedHeader
    case invalidTag
    case unsupportedVersion(Int)
    case truncatedChunkHeader(offset: Int)
    case invalidChunkName(offset: Int)
    case invalidChunkSize(name: String, size: Int)
    case chunkOutOfBounds(name: String)
    case duplicateChunk(String)
}

func walkD3LV127Chunks(_ data: Data) throws -> [D3LV127Chunk] {
    guard data.count >= 8 else { throw D3LV127Error.truncatedHeader }
    guard data.prefix(4).elementsEqual("D3LV".utf8) else { throw D3LV127Error.invalidTag }

    let version = Int(readD3LVInt32(data, at: 4))
    guard version == 127 else { throw D3LV127Error.unsupportedVersion(version) }

    var chunks: [D3LV127Chunk] = []
    var names = Set<String>()
    var offset = 8
    while offset < data.count {
        guard data.count - offset >= 8 else {
            throw D3LV127Error.truncatedChunkHeader(offset: offset)
        }
        let nameBytes = data[offset..<(offset + 4)]
        guard nameBytes.allSatisfy({ $0 >= 0x20 && $0 <= 0x7e }) else {
            throw D3LV127Error.invalidChunkName(offset: offset)
        }
        let name = String(decoding: nameBytes, as: UTF8.self)
        let declaredSize = Int(readD3LVInt32(data, at: offset + 4))
        guard declaredSize >= 4 else {
            throw D3LV127Error.invalidChunkSize(name: name, size: declaredSize)
        }
        let payloadStart = offset + 8
        let payloadCount = declaredSize - 4
        guard payloadCount <= data.count - payloadStart else {
            throw D3LV127Error.chunkOutOfBounds(name: name)
        }
        let payloadEnd = payloadStart + payloadCount
        guard names.insert(name).inserted else {
            throw D3LV127Error.duplicateChunk(name)
        }
        chunks.append(D3LV127Chunk(name: name, payloadRange: payloadStart..<payloadEnd))
        offset = payloadEnd
    }
    return chunks
}

private func readD3LVInt32(_ data: Data, at offset: Int) -> Int32 {
    let value = UInt32(data[offset])
        | UInt32(data[offset + 1]) << 8
        | UInt32(data[offset + 2]) << 16
        | UInt32(data[offset + 3]) << 24
    return Int32(bitPattern: value)
}
