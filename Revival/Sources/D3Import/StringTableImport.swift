// SPDX-License-Identifier: GPL-3.0-or-later
//
// Reads a module string table (`<module>.str`, for example `aigame.str`).
// Translated from Descent3/localization.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): CreateStringTable (:265) for the
// English language, with _parse_line_information (:516), _parse_string_tag
// (:536), _parse_escape_chars (:560), and GrowString (:656-790). The file
// is read in text mode: cfgetc (cfile/cfile.cpp:627) turns CR, CRLF, and LF
// into one newline, and cf_ReadString (:783) keeps at most 8,191 bytes of a
// line. A line ends its C string at a NUL byte.
//
// A line that starts with a language tag (`!=!` English, `!G!`, `!S!`,
// `!I!`, `!F!`) starts a string of that language and ends the one being
// read; `!/!` is a comment and ends it; an empty line is skipped; any other
// line continues the string being read, after a newline. Only English
// strings are kept, in file order. The string bytes map one to one to
// Unicode scalars (ISO 8859-1), so no byte is lost.

import Foundation

enum StringTableImportError: Error, Equatable {
    /// An escape the original reads past its buffer for: a backslash at the
    /// end of a line or before a character it does not know.
    case malformedEscape(fileName: String, line: Int)
}

/// CreateStringTable (localization.cpp:265) for English.
func parseStringTable(_ data: Data, fileName: String) throws -> [String] {
    let englishTag = Array("!=!".utf8)
    let otherTags = ["!G!", "!S!", "!I!", "!F!"].map { Array($0.utf8) }
    let commentTag = Array("!/!".utf8)
    var strings: [String] = []
    var reading: [UInt8]? = nil
    func finish() {
        if let bytes = reading {
            strings.append(String(bytes.map {
                Character(Unicode.Scalar($0))
            }))
        }
        reading = nil
    }
    for (lineNumber, fullLine) in stringTableTextLines(data).enumerated() {
        let stored = fullLine.prefix(8_191)
        let line = Array(stored.prefix { $0 != 0 })
        if line.starts(with: englishTag) {
            finish()
            reading = try parseStringTableEscapes(
                Array(line.dropFirst(englishTag.count)),
                fileName: fileName,
                line: lineNumber + 1
            )
        } else if otherTags.contains(where: { line.starts(with: $0) }) {
            finish()
        } else if line.starts(with: commentTag) {
            finish()
        } else if line.isEmpty {
            continue
        } else if reading != nil {
            // GrowString's += adds a newline before each later part.
            reading! += [0x0a] + (try parseStringTableEscapes(
                line,
                fileName: fileName,
                line: lineNumber + 1
            ))
        }
    }
    finish()
    return strings
}

/// _parse_escape_chars (localization.cpp:560): `\t`, `\n`, `\r`, `\"`, and
/// `\\` (either case), and `\` with decimal digits for that byte (modulo
/// 256). The C string ends at a NUL the escapes make.
private func parseStringTableEscapes(
    _ bytes: [UInt8],
    fileName: String,
    line: Int
) throws -> [UInt8] {
    var result: [UInt8] = []
    var index = 0
    while index < bytes.count {
        let byte = bytes[index]
        guard byte == 0x5c else {
            result.append(byte)
            index += 1
            continue
        }
        index += 1
        guard index < bytes.count else {
            throw StringTableImportError.malformedEscape(
                fileName: fileName,
                line: line
            )
        }
        switch bytes[index] {
        case 0x54, 0x74: result.append(0x09)
        case 0x4e, 0x6e: result.append(0x0a)
        case 0x52, 0x72: result.append(0x0d)
        case 0x22: result.append(0x22)
        case 0x5c: result.append(0x5c)
        case 0x30...0x39:
            var value: UInt8 = 0
            while index < bytes.count, (0x30...0x39).contains(bytes[index]) {
                value = value &* 10 &+ (bytes[index] - 0x30)
                index += 1
            }
            index -= 1
            result.append(value)
        default:
            throw StringTableImportError.malformedEscape(
                fileName: fileName,
                line: line
            )
        }
        index += 1
    }
    return Array(result.prefix { $0 != 0 })
}

/// The lines cf_ReadString returns in text mode: CR, CRLF, and LF each end
/// a line, and the loop stops at the end of the file, so a file that ends
/// with a newline has no empty last line.
private func stringTableTextLines(_ data: Data) -> [[UInt8]] {
    var lines: [[UInt8]] = []
    var current: [UInt8] = []
    var index = data.startIndex
    while index < data.endIndex {
        let byte = data[index]
        index = data.index(after: index)
        if byte == 0x0a || byte == 0x0d {
            if byte == 0x0d, index < data.endIndex, data[index] == 0x0a {
                index = data.index(after: index)
            }
            lines.append(current)
            current = []
        } else {
            current.append(byte)
        }
    }
    if !current.isEmpty {
        lines.append(current)
    }
    return lines
}
