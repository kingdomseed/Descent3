import XCTest

/// CreateStringTable (Descent3/localization.cpp:265-420) for a module
/// string table such as aigame.str, and the game module import that reads
/// it (Osiris_LoadGameModule, OsirisLoadandBind.cpp:1253). Synthetic data
/// only.
final class StringTableImportTests: XCTestCase {
    private func parse(_ text: String) throws -> [String] {
        try parseStringTable(Data(text.utf8), fileName: "test.str")
    }

    /// Only English strings are kept, in file order. A language tag or a
    /// comment ends the string being read; an empty line is skipped; any
    /// other line continues the string after a newline.
    func testKeepsEnglishStringsAndJoinsContinuationLines() throws {
        let strings = try parse("""
            !/! A header comment
            !=!First
            !G!Erste
            !=!Two
            lines

            here
            !F!Premier
            continued french
            !=!Third
            !/! ends Third
            not part of anything
            """)
        XCTAssertEqual(strings, ["First", "Two\nlines\nhere", "Third"])
    }

    /// An English tag with nothing after it gives an empty string.
    func testEmptyEnglishStringIsKept() throws {
        XCTAssertEqual(try parse("!=!\n!=!B\n"), ["", "B"])
    }

    /// _parse_escape_chars (localization.cpp:560): \t \n \r \" \\ in either
    /// case, and decimal byte values.
    func testEscapes() throws {
        let strings = try parse(#"!=!a\tb\Nc\rd\"e\\f\65\255"#)
        XCTAssertEqual(strings, ["a\tb\nc\rd\"e\\fA\u{ff}"])
    }

    /// A decimal escape of 0 ends the C string.
    func testNulEscapeEndsTheString() throws {
        XCTAssertEqual(try parse(#"!=!keep\0lost"#), ["keep"])
    }

    /// cfgetc turns CR, CRLF, and LF into one newline.
    func testLineEndings() throws {
        let data = Data("!=!A\r\nmore\rlast\n!=!B".utf8)
        XCTAssertEqual(
            try parseStringTable(data, fileName: "t.str"),
            ["A\nmore\nlast", "B"]
        )
    }

    /// A NUL byte ends the line's C string.
    func testNulByteEndsTheLine() throws {
        var data = Data("!=!before".utf8)
        data.append(0)
        data.append(contentsOf: Array("after\n!=!next".utf8))
        XCTAssertEqual(
            try parseStringTable(data, fileName: "t.str"),
            ["before", "next"]
        )
    }

    /// Bytes map one to one to Unicode scalars (ISO 8859-1).
    func testHighBytesAreLatin1() throws {
        var data = Data("!=!caf".utf8)
        data.append(0xe9)
        XCTAssertEqual(try parseStringTable(data, fileName: "t.str"), ["caf\u{e9}"])
    }

    /// The original reads past its buffer for a trailing or unknown escape;
    /// the import refuses the file.
    func testMalformedEscapesAreRefused() {
        XCTAssertThrowsError(try parse("!=!ok\n!=!bad\\")) { error in
            XCTAssertEqual(
                error as? StringTableImportError,
                .malformedEscape(fileName: "test.str", line: 2)
            )
        }
        XCTAssertThrowsError(try parse(#"!=!bad\q"#)) { error in
            XCTAssertEqual(
                error as? StringTableImportError,
                .malformedEscape(fileName: "test.str", line: 1)
            )
        }
    }

    /// The fixture table has the 146 strings the module reads.
    func testFixtureTableRoundTrips() throws {
        let text = fixtureAIGameStrings.map { "!=!" + $0 }.joined(separator: "\n")
        XCTAssertEqual(try parse(text), fixtureAIGameStrings)
    }

    private func levelReachingAIGame() -> Level {
        var info = fixtureGuideBotInfo
        info.moduleName = AIGame.moduleName
        return makeTrainingCameraMonitorLevel().addingObjectInfo(info)
    }

    private func addModules(_ level: Level,
                            archives: [LevelScriptArchive]) throws -> Level {
        try level.addingGameModules(
            archives: archives,
            genericPages: [:],
            soundPage: { _ in throw GameModuleImportError.unresolvedSound("") },
            soundClip: { _ in throw GameModuleImportError.unresolvedSound("") },
            weapon: { _ in throw GameModuleImportError.unresolvedWeapon("") },
            weaponModel: { _ in nil }
        )
    }

    /// A level whose objects bind no game module is unchanged.
    func testLevelWithoutGameModulesIsUnchanged() throws {
        let level = makeTrainingCameraMonitorLevel()
        XCTAssertEqual(level.reachedGameModules, [])
        XCTAssertEqual(try addModules(level, archives: []), level)
    }

    /// A reached module needs its string table in a library.
    func testMissingStringTableIsRefused() {
        let archive = makeLevelScriptArchive(
            relativePath: "extra.hog",
            entries: [("other.str", Data("!=!x".utf8))]
        )
        XCTAssertThrowsError(
            try addModules(levelReachingAIGame(), archives: [archive])
        ) { error in
            XCTAssertEqual(
                error as? GameModuleImportError,
                .missingStringTable("aigame.str")
            )
        }
    }

    /// The table must have every string the module reads (TXT(145)).
    func testShortStringTableIsRefused() {
        let text = fixtureAIGameStrings.prefix(145).map { "!=!" + $0 }
            .joined(separator: "\n")
        let archive = makeLevelScriptArchive(
            relativePath: "extra.hog",
            entries: [("AIGAME.STR", Data(text.utf8))]
        )
        XCTAssertThrowsError(
            try addModules(levelReachingAIGame(), archives: [archive])
        ) { error in
            XCTAssertEqual(
                error as? GameModuleImportError,
                .shortStringTable(module: "aigame", count: 145)
            )
        }
    }
}
