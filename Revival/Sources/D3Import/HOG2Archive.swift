// Copyright (C) 2026 Descent 3 Revival contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Source provenance: translated from cfile/hogfile.{h,cpp}, the HOG2 path in
// cfile/cfile.cpp, and tools/HogMaker/HogFormat.{h,cpp}.

import Foundation

struct HOG2Archive: Equatable {
    let entries: [HOG2Entry]
}

struct HOG2Entry: Equatable {
    let sourceName: String
    let flags: UInt32
    let timestamp: UInt32
    let payloadRange: Range<Int>
}

enum HOG2ParseError: Error, Equatable {
    case truncatedHeader
    case invalidTag
    case entryTableOffsetOverflow
    case truncatedEntryTable
    case payloadOverlapsEntryTable
    case payloadOffsetOutOfBounds
    case unterminatedName(index: Int)
    case nonASCIIName(index: Int)
    case entriesOutOfOrder(previous: String, current: String)
    case nameCollision(first: String, second: String)
    case payloadOffsetOverflow(index: Int)
    case truncatedPayload(index: Int)
    case trailingBytes
}

func parseHOG2(_ data: Data) throws -> HOG2Archive {
    let headerSize = 68
    let entrySize = 48

    guard data.count >= headerSize else {
        throw HOG2ParseError.truncatedHeader
    }
    guard data.prefix(4).elementsEqual("HOG2".utf8) else {
        throw HOG2ParseError.invalidTag
    }

    let entryCount = readLittleEndianUInt32(data, at: 4)
    let firstPayloadOffset = readLittleEndianUInt32(data, at: 8)
    let (tableByteCount, tableSizeOverflow) = entryCount.multipliedReportingOverflow(
        by: UInt32(entrySize)
    )
    let (tableEnd, tableOffsetOverflow) = UInt32(headerSize).addingReportingOverflow(tableByteCount)

    guard !tableSizeOverflow, !tableOffsetOverflow else {
        throw HOG2ParseError.entryTableOffsetOverflow
    }
    guard UInt64(tableEnd) <= UInt64(data.count) else {
        throw HOG2ParseError.truncatedEntryTable
    }
    guard firstPayloadOffset >= tableEnd else {
        throw HOG2ParseError.payloadOverlapsEntryTable
    }

    var entries: [HOG2Entry] = []
    entries.reserveCapacity(Int(entryCount))
    var payloadOffset = firstPayloadOffset
    var previousName: (source: String, folded: [UInt8])?

    for index in 0..<Int(entryCount) {
        let recordOffset = headerSize + index * entrySize
        let nameField = data[recordOffset..<(recordOffset + 36)]
        guard let terminator = nameField.firstIndex(of: 0) else {
            throw HOG2ParseError.unterminatedName(index: index)
        }
        let nameBytes = nameField[..<terminator]
        guard nameBytes.allSatisfy({ $0 < 0x80 }) else {
            throw HOG2ParseError.nonASCIIName(index: index)
        }
        let sourceName = String(decoding: nameBytes, as: UTF8.self)
        let foldedName = nameBytes.map(asciiLowercased)
        if let previousName {
            if foldedName == previousName.folded {
                throw HOG2ParseError.nameCollision(
                    first: previousName.source,
                    second: sourceName
                )
            }
            if foldedName.lexicographicallyPrecedes(previousName.folded) {
                throw HOG2ParseError.entriesOutOfOrder(
                    previous: previousName.source,
                    current: sourceName
                )
            }
        }
        previousName = (sourceName, foldedName)

        let flags = readLittleEndianUInt32(data, at: recordOffset + 36)
        let length = readLittleEndianUInt32(data, at: recordOffset + 40)
        let timestamp = readLittleEndianUInt32(data, at: recordOffset + 44)
        let (payloadEnd, payloadOffsetOverflow) = payloadOffset.addingReportingOverflow(length)

        guard !payloadOffsetOverflow else {
            throw HOG2ParseError.payloadOffsetOverflow(index: index)
        }
        guard UInt64(payloadOffset) <= UInt64(data.count) else {
            throw HOG2ParseError.payloadOffsetOutOfBounds
        }
        guard UInt64(payloadEnd) <= UInt64(data.count) else {
            throw HOG2ParseError.truncatedPayload(index: index)
        }

        entries.append(
            HOG2Entry(
                sourceName: sourceName,
                flags: flags,
                timestamp: timestamp,
                payloadRange: Int(payloadOffset)..<Int(payloadEnd)
            )
        )
        payloadOffset = payloadEnd
    }

    guard UInt64(payloadOffset) <= UInt64(data.count) else {
        throw HOG2ParseError.payloadOffsetOutOfBounds
    }
    guard UInt64(payloadOffset) == UInt64(data.count) else {
        throw HOG2ParseError.trailingBytes
    }

    return HOG2Archive(entries: entries)
}

private func readLittleEndianUInt32(_ data: Data, at offset: Int) -> UInt32 {
    UInt32(data[offset])
        | UInt32(data[offset + 1]) << 8
        | UInt32(data[offset + 2]) << 16
        | UInt32(data[offset + 3]) << 24
}

private func asciiLowercased(_ byte: UInt8) -> UInt8 {
    byte >= 0x41 && byte <= 0x5a ? byte + 0x20 : byte
}
