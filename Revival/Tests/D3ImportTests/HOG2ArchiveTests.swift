import Foundation
import XCTest

final class HOG2ArchiveTests: XCTestCase {
    func testRejectsTruncatedHeader() {
        XCTAssertThrowsError(try parseHOG2(Data(repeating: 0, count: 67))) { error in
            XCTAssertEqual(error as? HOG2ParseError, .truncatedHeader)
        }
    }

    func testRejectsInvalidTag() {
        var data = Data(repeating: 0, count: 68)
        data.replaceSubrange(0..<4, with: Data("HOG1".utf8))

        XCTAssertThrowsError(try parseHOG2(data)) { error in
            XCTAssertEqual(error as? HOG2ParseError, .invalidTag)
        }
    }

    func testRejectsEntryTableBeyondFile() {
        let data = makeHeader(entryCount: .max, firstPayloadOffset: 68)

        XCTAssertThrowsError(try parseHOG2(data)) { error in
            XCTAssertEqual(error as? HOG2ParseError, .truncatedEntryTable)
        }
    }

    func testRejectsTruncatedEntryTable() {
        let data = makeHeader(entryCount: 1, firstPayloadOffset: 116)

        XCTAssertThrowsError(try parseHOG2(data)) { error in
            XCTAssertEqual(error as? HOG2ParseError, .truncatedEntryTable)
        }
    }

    func testRejectsPayloadOverlappingEntryTable() {
        var data = makeHeader(entryCount: 1, firstPayloadOffset: 68)
        data.append(Data(repeating: 0, count: 48))

        XCTAssertThrowsError(try parseHOG2(data)) { error in
            XCTAssertEqual(error as? HOG2ParseError, .payloadOverlapsEntryTable)
        }
    }

    func testRejectsPayloadOffsetPastEndOfFile() {
        let data = makeHeader(entryCount: 0, firstPayloadOffset: 69)

        XCTAssertThrowsError(try parseHOG2(data)) { error in
            XCTAssertEqual(error as? HOG2ParseError, .payloadOffsetOutOfBounds)
        }
    }

    func testRejectsUnterminatedNameField() {
        let data = makeArchive(
            nameFields: [[UInt8](repeating: 0x61, count: 36)],
            payloads: [Data()]
        )

        XCTAssertThrowsError(try parseHOG2(data)) { error in
            XCTAssertEqual(error as? HOG2ParseError, .unterminatedName(index: 0))
        }
    }

    func testRejectsNonASCIIName() {
        let name = [0xc3, 0xa9, 0] + [UInt8](repeating: 0, count: 33)
        let data = makeArchive(nameFields: [name], payloads: [Data()])

        XCTAssertThrowsError(try parseHOG2(data)) { error in
            XCTAssertEqual(error as? HOG2ParseError, .nonASCIIName(index: 0))
        }
    }

    func testRejectsEntriesOutOfASCIIOrder() {
        let data = makeArchive(
            nameFields: [nameField("b.txt"), nameField("a.txt")],
            payloads: [Data(), Data()]
        )

        XCTAssertThrowsError(try parseHOG2(data)) { error in
            XCTAssertEqual(
                error as? HOG2ParseError,
                .entriesOutOfOrder(previous: "b.txt", current: "a.txt")
            )
        }
    }

    func testRejectsExactAndCaseFoldedNameCollisions() {
        for (first, second) in [("a.txt", "a.txt"), ("A.txt", "a.txt")] {
            let data = makeArchive(
                nameFields: [nameField(first), nameField(second)],
                payloads: [Data(), Data()]
            )

            XCTAssertThrowsError(try parseHOG2(data)) { error in
                XCTAssertEqual(
                    error as? HOG2ParseError,
                    .nameCollision(first: first, second: second)
                )
            }
        }
    }

    func testRejectsTruncatedPayload() {
        let data = makeArchive(
            nameFields: [nameField("short.bin")],
            payloads: [Data([1, 2, 3])],
            declaredLengths: [4]
        )

        XCTAssertThrowsError(try parseHOG2(data)) { error in
            XCTAssertEqual(error as? HOG2ParseError, .truncatedPayload(index: 0))
        }
    }

    func testRejectsPayloadOffsetPastEndBeforeReadingEntry() {
        var data = makeHeader(entryCount: 1, firstPayloadOffset: .max)
        data.append(contentsOf: nameField("past-end.bin"))
        data.appendLittleEndian(0)
        data.appendLittleEndian(1)
        data.appendLittleEndian(0)

        XCTAssertThrowsError(try parseHOG2(data)) { error in
            XCTAssertEqual(error as? HOG2ParseError, .payloadOffsetOutOfBounds)
        }
    }

    func testRejectsUndeclaredTrailingBytes() {
        let data = makeArchive(
            nameFields: [nameField("empty.bin")],
            payloads: [Data()],
            trailingBytes: Data([0xff])
        )

        XCTAssertThrowsError(try parseHOG2(data)) { error in
            XCTAssertEqual(error as? HOG2ParseError, .trailingBytes)
        }
    }

    func testReadsZeroEntryArchive() throws {
        let archive = try parseHOG2(makeHeader(entryCount: 0, firstPayloadOffset: 68))

        XCTAssertEqual(archive.entries, [])
    }

    func testPreservesZeroLengthPayloadInTableOrder() throws {
        let data = makeArchive(
            nameFields: [nameField("empty.bin"), nameField("full.bin")],
            payloads: [Data(), Data([0x7f])]
        )

        let archive = try parseHOG2(data)

        XCTAssertEqual(archive.entries.map(\.payloadRange), [164..<164, 164..<165])
    }

    func testReadsPayloadAfterDeclaredGap() throws {
        let data = makeArchive(
            nameFields: [nameField("gap.bin")],
            payloads: [Data([0x7f])],
            firstPayloadOffset: 120
        )

        let archive = try parseHOG2(data)

        XCTAssertEqual(archive.entries.first?.payloadRange, 120..<121)
    }

    func testReadsTrackedHOG2Index() throws {
        let fixtureURL = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "test", withExtension: "hog")
        )
        let fixture = try Data(contentsOf: fixtureURL)

        let archive = try parseHOG2(fixture)

        XCTAssertEqual(archive.entries.count, 1)
        let entry = try XCTUnwrap(archive.entries.first)
        XCTAssertEqual(entry.sourceName, "lowercase.txt")
        XCTAssertEqual(entry.flags, 0)
        XCTAssertEqual(entry.timestamp, 0x667f1e91)
        XCTAssertEqual(entry.payloadRange, 116..<120)
        XCTAssertEqual(fixture.subdata(in: entry.payloadRange), Data("TEST".utf8))
    }
}

private func makeHeader(entryCount: UInt32, firstPayloadOffset: UInt32) -> Data {
    var data = Data("HOG2".utf8)
    data.appendLittleEndian(entryCount)
    data.appendLittleEndian(firstPayloadOffset)
    data.append(contentsOf: repeatElement(0xff, count: 56))
    return data
}

private func makeArchive(
    nameFields: [[UInt8]],
    payloads: [Data],
    declaredLengths: [UInt32]? = nil,
    firstPayloadOffset: UInt32? = nil,
    trailingBytes: Data = Data()
) -> Data {
    precondition(nameFields.count == payloads.count)
    precondition(nameFields.allSatisfy { $0.count == 36 })
    precondition(declaredLengths == nil || declaredLengths?.count == payloads.count)

    let tableEnd = UInt32(68 + nameFields.count * 48)
    let payloadOffset = firstPayloadOffset ?? tableEnd
    var data = makeHeader(entryCount: UInt32(nameFields.count), firstPayloadOffset: payloadOffset)

    for index in nameFields.indices {
        data.append(contentsOf: nameFields[index])
        data.appendLittleEndian(0)
        data.appendLittleEndian(declaredLengths?[index] ?? UInt32(payloads[index].count))
        data.appendLittleEndian(0)
    }

    if data.count < Int(payloadOffset) {
        data.append(Data(repeating: 0, count: Int(payloadOffset) - data.count))
    }
    for payload in payloads {
        data.append(payload)
    }
    data.append(trailingBytes)
    return data
}

private func nameField(_ name: String) -> [UInt8] {
    let bytes = [UInt8](name.utf8)
    precondition(bytes.count < 36)
    return bytes + [0] + [UInt8](repeating: 0, count: 35 - bytes.count)
}

private extension Data {
    mutating func appendLittleEndian(_ value: UInt32) {
        append(UInt8(truncatingIfNeeded: value))
        append(UInt8(truncatingIfNeeded: value >> 8))
        append(UInt8(truncatingIfNeeded: value >> 16))
        append(UInt8(truncatingIfNeeded: value >> 24))
    }
}
